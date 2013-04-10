//
//  HoccerTalkBackend.m
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HoccerTalkBackend.h"

#import "JsonRpcWebSocket.h"
#import "TalkMessage.h"
#import "Delivery.h"
#import "Contact.h"
#import "AppDelegate.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "Attachment.h"
#import "Environment.h"
#import "Relationship.h"
#import "HTUserDefaults.h"
#import "NSData+CommonCrypto.h"
#import "NSData_Base64Extensions.h"
#import "RSA.h"

@interface HoccerTalkBackend ()
{
    JsonRpcWebSocket * _serverConnection;
    BOOL _isConnected;
    double _backoffTime;
    NSString * _apnsDeviceToken;
    NSURLConnection * _avatarUploadConnection;
    NSString * _avatarUploadURL;
    NSInteger _avatarBytesUploaded;
    NSInteger _avatarBytesTotal;
}

- (void) identify;

@end

@implementation HoccerTalkBackend

- (id) initWithDelegate: (AppDelegate *) theAppDelegate {
    self = [super init];
    if (self != nil) {
        _backoffTime = 0.0;
        _isConnected = NO;
        _apnsDeviceToken = nil;
        _serverConnection = [[JsonRpcWebSocket alloc] initWithURLRequest: [self urlRequest]];
        _serverConnection.delegate = self;
        [_serverConnection registerIncomingCall: @"incomingDelivery" withSelector:@selector(incomingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"outgoingDelivery" withSelector:@selector(outgoingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"pushNotRegistered" withSelector:@selector(pushNotRegistered:) isNotification: YES];
        _delegate = theAppDelegate;
    }
    return self;
}

// TODO: contact should be an array of contacts
- (TalkMessage*) sendMessage:(NSString *) text toContact: (Contact*) contact withAttachment: (Attachment*) attachment {
    TalkMessage * message =  (TalkMessage*)[NSEntityDescription insertNewObjectForEntityForName: [TalkMessage entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    message.body = text;
    message.timeStamp = [NSDate date];
    message.contact = contact;
    message.isOutgoing = @YES;
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    message.messageId = @"";
    message.messageTag = [NSString stringWithUUID];

    attachment.remoteURL =  [[self newUploadURL] absoluteString];
    attachment.transferSize = 0;

    message.attachment = attachment;
    NSLog(@"sendMessage: message.attachment = %@", message.attachment);

    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    delivery.receiver = contact;

    contact.latestMessageTime = message.timeStamp;

    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];

    if (_isConnected) {
        [self deliveryRequest: message withDeliveries: @[delivery]];
    }
    [attachment upload];
    
    return message;
}

- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary {
    // Ignore duplicate messages. This happens if a message is offered to us by the server multiple times
    // while we are in the background. These messages end up in the input buffer of the socket and are delivered
    // when we enter foreground before the connection times out. Another solution would be to disconnect while
    // we are in background but currently I prefer it this way.
    NSError *error;
    NSDictionary * vars = @{ @"messageId" : messageDictionary[@"messageId"]};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"MessageByMessageId" substitutionVariables: vars];
    NSArray *messages = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (messages == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    if (messages.count > 0) {
        NSLog(@"receiveMessage: already have message with id %@", vars[@"messageId"]);
        // TODO: send delivery confirm (again)?
        return;
    }

    TalkMessage * message = [NSEntityDescription insertNewObjectForEntityForName: [TalkMessage entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    Delivery * delivery = [NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    
    Attachment * attachment = nil;
    if (messageDictionary[@"attachmentUrl"] != nil) {
        attachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: self.delegate.managedObjectContext];
        message.attachment = attachment;
    }

    vars = @{ @"clientId" : messageDictionary[@"senderId"]};
    fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"ContactByClientId" substitutionVariables: vars];
    error = nil;
    NSArray *contacts = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (contacts == nil)
    {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Contact * contact = nil;
    // TODO: getr rid of this ...
    if (contacts.count > 0) {
        contact = contacts[0];
    } else {
        NSLog(@"Ignoring message from unknown clientId %@", messageDictionary[@"senderId"]);
        [self.delegate.managedObjectContext deleteObject: message];
        [self.delegate.managedObjectContext deleteObject: delivery];
        return;
    }

    [delivery updateWithDictionary: deliveryDictionary];

    message.isOutgoing = @NO;
    message.isRead = @NO;
    message.timeStamp = [NSDate date]; // TODO: use actual timestamp
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    message.contact = contact;
    [contact.messages addObject: message];
    [message updateWithDictionary: messageDictionary];

    contact.latestMessageTime = message.timeStamp;

    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];
    [self deliveryConfirm: message.messageId withDelivery: delivery];
    
    if (attachment) {
        [NSTimer scheduledTimerWithTimeInterval:2.0 target:attachment selector: @selector(downloadLater:) userInfo:nil repeats:NO];
        //[attachment download];
    }
}

- (void) gotAPNSDeviceToken: (NSString*) deviceToken {
    if (_isConnected) {
        [self registerApns: deviceToken];
    } else {
        _apnsDeviceToken = deviceToken;
    }
}

- (void) start {
    [_serverConnection open];
}

- (void) reconnectWitBackoff {
    NSLog(@"reconnecting in %f seconds", _backoffTime);
    if (_backoffTime == 0) {
        [self reconnect];
        _backoffTime = (double)rand() / RAND_MAX;
    } else {
        [NSTimer scheduledTimerWithTimeInterval: _backoffTime target: self selector: @selector(reconnect) userInfo: nil repeats: NO];
        _backoffTime = MIN(2 * _backoffTime, 10);
    }
}

- (void) reconnect {
    [_serverConnection reopenWithURLRequest: [self urlRequest]];
}

- (NSURLRequest*) urlRequest {
    // TODO: make server adjustable
    NSURL * url = [NSURL URLWithString: [[Environment sharedEnvironment] talkServer]];
    return [[NSURLRequest alloc] initWithURL: url];
}

- (void) flushPendingMessages {
    // fetch all deliveries with state 'new'
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestTemplateForName:@"DeliveriesWithStateNew"];
    NSError *error;
    NSArray *deliveries = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"Fetch request 'DeliveriesWithStateNew' failed: %@", error);
        abort();
    }
    // collect all messages that have a delivery with state 'new'
    NSMutableSet * pendingMessages = [[NSMutableSet alloc] init];
    for (Delivery * delivery in deliveries) {
        if (! [pendingMessages containsObject: delivery.message]) {
            [pendingMessages addObject: delivery.message];
        }
    }
    // paranoid but safe: for each message collect those deliveries that have state 'new' and send them out
    for (TalkMessage * message in pendingMessages) {
        NSMutableArray * newDeliveries = [[NSMutableArray alloc] init];
        for (Delivery * delivery in message.deliveries) {
            if ([delivery.state isEqualToString: kDeliveryStateNew]) {
                [newDeliveries addObject: delivery];
            }
        }
        [self deliveryRequest: message withDeliveries: newDeliveries];
    }
}


- (NSDate*) getLatestChangeDateFromRelationships {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: [Relationship entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [request setEntity:entity];
    [request setResultType:NSDictionaryResultType];
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:@"lastChanged"];
    NSExpression *maxLastChangedExpression = [NSExpression expressionForFunction:@"max:"
                                                                  arguments:[NSArray arrayWithObject:keyPathExpression]];
    NSExpressionDescription *expressionDescription = [[NSExpressionDescription alloc] init];
    [expressionDescription setName:@"latestChange"];
    [expressionDescription setExpression: maxLastChangedExpression];
    [expressionDescription setExpressionResultType: NSDateAttributeType];

    [request setPropertiesToFetch:[NSArray arrayWithObject:
                                        expressionDescription]];
    NSError *error = nil;
    NSArray *fetchResults = [self.delegate.managedObjectContext
                             executeFetchRequest:request
                             error:&error];

    NSDate * latest = [[fetchResults lastObject] valueForKey:@"latestChange"];
    if (latest == nil) {
        NSLog(@"Failed to get last relationship changed date: %@", error);
        abort();
    }
    return latest;
}


- (void) updateRelationships {
    NSDate * latestChange = [self getLatestChangeDateFromRelationships];
    NSLog(@"latest date %@", latestChange);
    [self getRelationships: latestChange relationshipHandler:^(NSArray * changedRelationships) {
    }];
}

#pragma mark - Attachment upload and download

- (void) flushPendingFiletransfers {
    [self performSelectorOnMainThread:@selector(uploadAvatarIfNeeded) withObject:nil waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(flushPendingAttachmentUploads) withObject:nil waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(flushPendingAttachmentDownloads) withObject:nil waitUntilDone:NO];
}


- (void) flushPendingAttachmentUploads {
    // fetch all not yet transferred uploads
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestTemplateForName:@"AttachmentsNotUploaded"];
    NSError *error;
    NSArray *unfinishedAttachments = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (unfinishedAttachments == nil)
    {
        NSLog(@"Fetch request 'AttachmentsNotUploaded' failed: %@", error);
        abort();
    }
    for (Attachment * attachment in unfinishedAttachments) {
        [attachment upload];
    }
}

- (void) flushPendingAttachmentDownloads {
    // fetch all not yet transferred uploads
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestTemplateForName:@"AttachmentsNotDownloaded"];
    NSError *error;
    NSArray *unfinishedAttachments = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (unfinishedAttachments == nil)
    {
        NSLog(@"Fetch request 'AttachmentsNotDownloaded' failed: %@", error);
        abort();
    }
    for (Attachment * attachment in unfinishedAttachments) {
        [attachment download];
    }
}

- (void) downloadFinished:(Attachment *)theAttachment {
    NSLog(@"downloadFinished of %@", theAttachment);
    [self.delegate.managedObjectContext refreshObject: theAttachment.message mergeChanges:YES];
}


- (NSURL *) newUploadURL {
    // NSString * myURL = [kFileCacheDevelopmentURI stringByAppendingString:[NSString stringWithUUID]];
    NSString * myURL = [[[Environment sharedEnvironment] fileCacheURI] stringByAppendingPathComponent:[NSString stringWithUUID]];
    return [NSURL URLWithString: myURL];
}

- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                             payload:(NSData *)payload
                             headers:(NSDictionary *)headers
{
	
    NSLog(@"httpRequest method: %@ url: %@", method, URLString);
    NSURL *url = [NSURL URLWithString:URLString];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	
	[request addValue:self.delegate.userAgent forHTTPHeaderField:@"User-Agent"];
	for (NSString *key in headers) {
		[request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
	}
    
	[request setHTTPMethod:method];
	[request setHTTPBody:payload];
	[request setTimeoutInterval:60];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    return request;
}

#pragma mark - Outgoing RPC Calls

- (void) identify {
    NSString * clientId = [self.delegate clientId];
    NSLog(@"identify() clientId: %@", clientId);
    [_serverConnection invoke: @"identify" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"identify(): got result: %@", responseOrError);
            if (_apnsDeviceToken) {
                [self registerApns: _apnsDeviceToken];
                _apnsDeviceToken = nil; // XXX: this is not nice...
            }
            [self flushPendingMessages];
            [self flushPendingFiletransfers];
            [self updateRelationships];
            _isConnected = YES;
        } else {
            NSLog(@"identify(): got error: %@", responseOrError);
        }
    }];
}

- (void) deliveryRequest: (TalkMessage*) message withDeliveries: (NSArray*) deliveries {
    NSMutableDictionary * messageDict = [message rpcDictionary];
    NSMutableArray * deliveryDicts = [[NSMutableArray alloc] init];
    for (Delivery * delivery in deliveries) {
        [deliveryDicts addObject: [delivery rpcDictionary]];
    }
    NSLog(@"deliveryRequest: %@", messageDict);
    [_serverConnection invoke: @"deliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"deliveryRequest() returned deliveries: %@", responseOrError);
            NSArray * updatedDeliveryDicts = (NSArray*)responseOrError;
            int i = 0;
            for (Delivery * delivery in deliveries) {
                [delivery updateWithDictionary: updatedDeliveryDicts[i++]];
            }
        } else {
            NSLog(@"deliveryRequest failed: %@", responseOrError);
        }
    }];
}

- (void) deliveryConfirm: (NSString*) messageId withDelivery: (Delivery*) delivery {
    NSLog(@"deliveryConfirm: %@", delivery);
    [_serverConnection invoke: @"deliveryConfirm" withParams: @[messageId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"deliveryConfirm() returned deliveries: %@", responseOrError);
            [delivery updateWithDictionary: responseOrError];
        } else {
            NSLog(@"deliveryConfirm() failed: %@", responseOrError);
        }
    }];
}

- (void) updatePresence: (NSString*) clientName withStatus: clientStatus withAvatar: avatarURL {
    NSLog(@"updatePresence: %@, %@, %@", clientName, clientStatus, avatarURL);
    NSDictionary *params = @{
                             @"clientName" : clientName,
                             @"clientStatus" : clientStatus,
                             @"avatarUrl" : avatarURL,
                             };
    [_serverConnection invoke: @"updatePresence" withParams: params onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"updatePresence() got result: %@", responseOrError);
        } else {
            NSLog(@"updatePresence() failed: %@", responseOrError);
        }
    }];
}

- (void) updatePresence {
    // NSString * myAvatarURL =[[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarURL];
    NSString * myAvatarURL = [self calcAvatarURL];
    NSString * myNickName = [[HTUserDefaults standardUserDefaults] objectForKey: kHTNickName];
   // NSString * myStatus = [[HTUserDefaults standardUserDefaults] objectForKey: kHTUserStatus];
    NSString * myStatus = @"I am.";
    
    [self updatePresence: myNickName withStatus:myStatus withAvatar:myAvatarURL];
}


- (void) updateKey: (NSString*) publicKey {
    NSLog(@"updateKey: %@", publicKey);
    NSDictionary *params = @{
                             @"publicKey" : publicKey
                             };
    //[_serverConnection invoke: @"updateKey" withParams: @[publicKey] onResponse: ^(id responseOrError, BOOL success) {
    [_serverConnection invoke: @"updateKey" withParams: params onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"updateKey() got result: %@", responseOrError);
        } else {
            NSLog(@"updateKey() failed: %@", responseOrError);
        }
    }];
}
- (void) updateKey {

    NSData * myKeyBits = [[RSA sharedInstance] getPublicKeyBits];
    [self updateKey: [myKeyBits asBase64EncodedString]];
}

- (void) registerApns: (NSString*) token {
    NSLog(@"registerApns: %@", token);
    [_serverConnection invoke: @"registerApns" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"registerApns(): got result: %@", responseOrError);
        } else {
            // TODO retry?
            NSLog(@"registerApns(): failed: %@", responseOrError);
        }
    }];
}

- (void) unregisterApns {
    NSLog(@"unregisterApns:");
    [_serverConnection invoke: @"unregisterApns" withParams: @[] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"unregisterApns(): got result: %@", responseOrError);
        } else {
            // TODO retry?
            NSLog(@"registerApns(): failed: %@", responseOrError);
        }
    }];
}

- (void) generateToken: (NSString*) purpose validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler {
    NSLog(@"generateToken:");
    [_serverConnection invoke: @"generateToken" withParams: @[purpose, [NSNumber numberWithInt:seconds]] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"generateToken(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"generateToken(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) pairByToken: (NSString*) token pairingHandler: (PairingHandler) handler {
    NSLog(@"pairByToken:");
    [_serverConnection invoke: @"pairByToken" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"pairByToken(): got result: %@", responseOrError);
            handler([responseOrError boolValue]);
        } else {
            NSLog(@"pairByToken(): failed: %@", responseOrError);
            handler(NO);
        }
    }];

}

- (void) getRelationships: (NSDate*) lastKnown relationshipHandler: (RelationshipHandler) handler {
    NSLog(@"getRelationships:");
    NSNumber * lastKnownMillis = [NSNumber numberWithLongLong: [lastKnown timeIntervalSince1970] * 1000];
    [_serverConnection invoke: @"getRelationships" withParams: @[lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"getRelationships(): got result: %@", responseOrError);
            //handler([responseOrError boolValue]);
        } else {
            NSLog(@"getRelationships(): failed: %@", responseOrError);
            //handler(NO);
        }
    }];
}

#pragma mark - Incoming RPC Calls

- (void) incomingDelivery: (NSArray*) params {
    if (params.count != 2) {
        NSLog(@"incomingDelivery requires an array of two parameters (delivery, message), but got %d parameters.", params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"incomingDelivery: parameter 0 must be an object");
        return;
    }
    NSDictionary * deliveryDict = params[0];
    if ( ! [params[1] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"incomingDelivery: parameter 1 must be an object");
        return;
    }
    NSDictionary * messageDict = params[1];
    [self receiveMessage: messageDict withDelivery: deliveryDict];
}

- (void) outgoingDelivery: (NSArray*) params {
    /* TODO: implement outgoing delivery
    if (params.count != 1) {
        NSLog(@"outgoing requires an array of two parameters (delivery, message), but got %d parameters.", params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        return;
    }
    NSDictionary * deliveryDict = params[0];
     */
    NSLog(@"================= outgoingDelivery() called");
}

- (void) pushNotRegistered: (NSArray*) unused {
    NSString * apnDeviceToken = [self.delegate apnDeviceToken];
    if (apnDeviceToken != nil) {
        [self registerApns: apnDeviceToken];
    }
}


#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@", error);
    _isConnected = NO;
    // if we get an error add a little initial backoff
    if (_backoffTime == 0) {
        _backoffTime = (double)rand() / RAND_MAX;
    }
    [self reconnectWitBackoff];
}

- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error {
    NSLog(@"didReceiveInvalidJsonRpcMessage: %@", error);
}

- (void) webSocketDidOpen: (SRWebSocket*) webSocket {
    //NSLog(@"webSocketDidOpen");
    _backoffTime = 0.0;
    [self identify];
    [self updatePresence];
    [self updateKey];
}

- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket didCloseWithCode %d reason: %@ clean: %d", code, reason, wasClean);
    _isConnected = NO;
    [self reconnectWitBackoff];
}

- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

#pragma mark - Avatar uploading

- (void) uploadAvatarIfNeeded {
    NSString * myDesiredURL = [self calcAvatarURL];
    NSString * myCurrentAvatarURL =[[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarURL];
    if (![myCurrentAvatarURL isEqualToString: myDesiredURL]) {
        [self uploadAvatar: myDesiredURL];
    }
}

- (void) uploadAvatar: (NSString*)toURL {
    if (self.avatarUploadConnection != nil) {
        NSLog(@"avatar is still being uploaded");
        return;
    }
    NSData * myAvatarData = [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarImage];
    NSLog(@"uploadAvatar starting");
    _avatarBytesTotal = [myAvatarData length];
    _avatarUploadURL = toURL;
    NSURLRequest *myRequest  = [self httpRequest:@"PUT"
                                     absoluteURI:toURL
                                         payload:myAvatarData
                                         headers:[self httpHeaderWithContentLength: _avatarBytesTotal]
                                ];
    _avatarBytesUploaded = 0;
    _avatarUploadConnection = [NSURLConnection connectionWithRequest:myRequest delegate:self];
}

-(NSDictionary*) httpHeaderWithContentLength: (NSUInteger) theLength {
	
    NSDictionary * headers = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSString stringWithFormat:@"%u", theLength], @"Content-Length",
                              nil
                              ];
    return headers;
    
}

- (NSString *) calcAvatarURL {
    NSMutableData * myAvatarData = [NSMutableData dataWithData:[[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarImage]];
    NSString * myClientID =[[HTUserDefaults standardUserDefaults] objectForKey: kHTClientId];
    [myAvatarData appendData:[myClientID dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSData * myHash = [myAvatarData SHA256Hash];
    NSString * myAvatarFileName = [myHash hexadecimalString];
    NSString * myURL = [[[Environment sharedEnvironment] fileCacheURI] stringByAppendingPathComponent:myAvatarFileName];
    return myURL;
    // return [NSURL URLWithString: myURL];
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (connection == _avatarUploadConnection) {
        NSLog(@"_avatarUploadConnection didReceiveResponse %@, status=%ld, %@",
              httpResponse, (long)[httpResponse statusCode],
              [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
    } else {
        NSLog(@"ERROR: HoccerTalkBackend didReceiveResponse without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == _avatarUploadConnection) {
        /*
        NSLog(@"_avatarUploadConnection didReceiveData len=%lu", (unsigned long)[data length]);
        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            NSURL * myURL = [NSURL URLWithString: self.ownedURL];
            NSString * myPath = [myURL path];
            NSOutputStream * stream = [[NSOutputStream alloc] initToFileAtPath: myPath append:YES];
            [stream open];
            NSUInteger left = [data length];
            NSUInteger nwr = 0;
            do {
                nwr = [stream write:[data bytes] maxLength:left];
                if (-1 == nwr) break;
                left -= nwr;
            } while (left > 0);
            if (left) {
                NSLog(@"ERROR: HoccerTalkBackend didReceiveData, stream error: %@", [stream streamError]);
            }
            [stream close];
        } else {
            NSLog(@"ERROR: HoccerTalkBackend didReceiveData on outgoing (upload) connection");
        }
         */
    } else {
        NSLog(@"ERROR: HoccerTalkBackend didReceiveData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == _avatarUploadConnection) {
        NSLog(@"_avatarUploadConnection didSendBodyData %d", bytesWritten);
        _avatarBytesUploaded = totalBytesWritten;
    } else {
        NSLog(@"ERROR: HoccerTalkBackend didSendBodyData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == _avatarUploadConnection) {
        NSLog(@"_avatarUploadConnection didFailWithError %@", error);
        _avatarUploadConnection = nil;
    } else {
        NSLog(@"ERROR: HoccerTalkBackend didFailWithError without valid connection");
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == _avatarUploadConnection) {
        NSLog(@"_avatarUploadConnection connectionDidFinishLoading %@", connection);
        _avatarUploadConnection = nil;
        if (_avatarBytesUploaded == _avatarBytesTotal) {
            // set avatar url to new successfully uploaded version
            [[HTUserDefaults standardUserDefaults] setObject: _avatarUploadURL forKey: kHTAvatarURL];
            [[HTUserDefaults standardUserDefaults] synchronize];
            NSLog(@"_avatarUploadConnection successfully uploaded avatar of size %d", _avatarBytesTotal);
        } else {
            NSLog(@"ERROR: _avatarUploadConnection only uploaded %d bytes, should be %d",_avatarBytesUploaded, _avatarBytesTotal);
        }
        /*
        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            // finish download
            NSError *myError = nil;
            self.transferSize = [Attachment fileSize: self.ownedURL withError:&myError];
            
            if ([self.transferSize isEqualToNumber: self.contentSize]) {
                NSLog(@"Attachment transferConnection connectionDidFinishLoading successfully downloaded attachment, size=%@", self.contentSize);
                self.localURL = self.ownedURL;
                // TODO: maybe do some UI refresh here, or use an observer for this
                [_chatBackend performSelectorOnMainThread:@selector(downloadFinished:) withObject:self waitUntilDone:NO];
                // [_chatBackend downloadFinished: self];
                NSLog(@"Attachment transferConnection connectionDidFinishLoading, notified backend, attachment=%@", self);
            } else {
                NSLog(@"Attachment transferConnection connectionDidFinishLoading download failed, contentSize=%@, self.transferSize=%@", self.contentSize, self.transferSize);
                // TODO: trigger some retry
            }
        }
     */
    } else {
        NSLog(@"ERROR: Attachment transferConnection connectionDidFinishLoading without valid connection");
    }
}


@end
