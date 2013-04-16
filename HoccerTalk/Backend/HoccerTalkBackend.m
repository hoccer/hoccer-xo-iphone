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
#import "Attachment.h"
#import "Invite.h"
#import "AppDelegate.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "Environment.h"
#import "HTUserDefaults.h"
#import "NSData+CommonCrypto.h"
#import "NSData+Base64.h"
#import "RSA.h"
#import "NSString+URLHelper.h"
#import "NSDictionary+CSURLParams.h"
#import "ObjCSRP/HCSRP.h"

const NSString * const kHXOProtocol = @"com.hoccer.talk.v1";

typedef enum BackendStates {
    kBackendStopped,
    kBackendConnecting,
    kBackendRegistering,
    kBackendAuthenticating,
    kBackendReady,
    kBackendStopping
} BackendState;

@interface HoccerTalkBackend ()
{
    JsonRpcWebSocket * _serverConnection;
    BackendState       _state;
    double             _backoffTime;
    NSString *         _apnsDeviceToken;
    NSURLConnection *  _avatarUploadConnection;
    NSString *         _avatarUploadURL;
    NSInteger          _avatarBytesUploaded;
    NSInteger          _avatarBytesTotal;
    BOOL               _performRegistration;
    HCSRPUser *        _srpUser;
}

- (void) identify;

@end

@implementation HoccerTalkBackend

- (id) initWithDelegate: (AppDelegate *) theAppDelegate {
    self = [super init];
    if (self != nil) {
        _backoffTime = 0.0;
        _state = kBackendStopped;
        _serverConnection = [[JsonRpcWebSocket alloc] init];
        _serverConnection.delegate = self;
        _apnsDeviceToken = nil;
        [_serverConnection registerIncomingCall: @"incomingDelivery"  withSelector:@selector(incomingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"outgoingDelivery"  withSelector:@selector(outgoingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"pushNotRegistered" withSelector:@selector(pushNotRegistered:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"presenceUpdated"   withSelector:@selector(presenceUpdatedNotification:) isNotification: YES];
        _delegate = theAppDelegate;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(profileUpdatedByUser:)
                                                     name:@"profileUpdatedByUser"
                                                   object:nil];
    }
    return self;
}

- (NSString*) stateString: (BackendState) state {
    switch (state) {
        case kBackendStopped:
            return @"stopped";
            break;
        case kBackendConnecting:
            return @"connecting";
            break;
        case kBackendRegistering:
            return @"registering";
            break;
        case kBackendAuthenticating:
            return @"authenticating";
            break;
        case kBackendReady:
            return @"ready";
            break;
        case kBackendStopping:
            return @"stopping";
            break;
    }
}

- (void) setState: (BackendState) state {
    NSLog(@"backend state %@ -> %@", [self stateString: _state], [self stateString: state]);
    _state = state;
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
    // NSLog(@"sendMessage: message.attachment = %@", message.attachment);

    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    delivery.receiver = contact;

    contact.latestMessageTime = message.timeStamp;
    [message setupOutgoingEncryption];

    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];

    if (_state == kBackendReady) {
        [self deliveryRequest: message withDeliveries: @[delivery]];
    }
    
    if ([attachment.contentSize longLongValue] < [[[HTUserDefaults standardUserDefaults] valueForKey:kHTAutoUploadLimit] longLongValue])
    {
        [attachment upload];
    }
    
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
    if (![deliveryDictionary[@"keyCiphertext"] isKindOfClass:[NSString class]]) {
        NSLog(@"receiveMessage: ignoring received message without keyCiphertext, id= %@", vars[@"messageId"]);
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

    // TODO: Refactor: use function getContactByClientId below
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
        if ([attachment.contentSize longLongValue] < [[[HTUserDefaults standardUserDefaults] valueForKey:kHTAutoDownloadLimit] longLongValue])
        {
            [NSTimer scheduledTimerWithTimeInterval:2.0 target:attachment selector: @selector(downloadLater:) userInfo:nil repeats:NO];
        }
    }
}

- (void) performRegistration {
    NSLog(@"performRegistration");
    GenerateIdHandler handler = ^(NSString * theId) {
#ifdef HXO_USE_USERNAME_BASED_AUTHENICATION
        [self didRegister: YES];
#else
        [[HTUserDefaults standardUserDefaults] setValue: theId forKey: kHTClientId];
        _srpUser = [[HCSRPUser alloc] initWithUserName: theId andPassword: [self getPassword]];
        NSData * salt;
        NSData * verifier;
        [_srpUser salt: & salt andVerificationKey: & verifier forPassword:[self getPassword]];
        [[HTUserDefaults standardUserDefaults] setValue: [salt hexadecimalString] forKey: kHTSrpSalt];
        [self srpRegisterWithVerifier: [verifier hexadecimalString] andSalt: [salt hexadecimalString]];
#endif
    };
#ifdef HXO_USE_USER_DEFINED_CREDENTIALS
    handler([[HTUserDefaults standardUserDefaults] valueForKey: kHTClientId]);
#else
    [self generateId: handler];
#endif
    //[self identify];
}

- (void) didRegister: (BOOL) success {
    NSLog(@"didRegister: %d", success);
    if (success) {
        _performRegistration = NO;
        [self startAuthentication];
    } else {
        NSLog(@"ERROR: registration failed. What now?");
    }
    
}

- (void) startAuthentication {
    [self setState: kBackendAuthenticating];
#ifdef HXO_USE_USERNAME_BASED_AUTHENICATION
    [self identify];
#else
    NSData * A = [_srpUser startAuthentication];
    [self srpPhase1WithClientId: [[HTUserDefaults standardUserDefaults] valueForKey: kHTClientId] A: [A hexadecimalString] andHandler:^(NSString * challenge) {
        if (challenge == nil) {
            NSLog(@"SRP phase 1 failed");
        } else {
            NSData * salt = [NSData dataWithHexadecimalString: [[HTUserDefaults standardUserDefaults] valueForKey: kHTSrpSalt]];
            NSData * B = [NSData dataWithHexadecimalString: challenge];
            NSData * M = [_srpUser processChallenge: salt B: B];
            if (M == nil) {
                NSLog(@"SRP-6a safety check violation! Closing connection.");
                // possible man in the middle attack ... trigger reconnect by closing the socket
                [self stopAndRetry];
            } else {
                [self srpPhase2: [M hexadecimalString] handler:^(NSString * HAMKString) {
                    NSData * HAMK = [NSData dataWithHexadecimalString: HAMKString];
                    [_srpUser verifySession: HAMK];
                    [self didFinishLogin: _srpUser.isAuthenticated];
                }];
            }
        }
    }];
#endif
}

- (void) didFinishLogin: (BOOL) authenticated{
    if (authenticated) {
        // NSLog(@"identify(): got result: %@", responseOrError);
        if (_apnsDeviceToken) {
            [self registerApns: _apnsDeviceToken];
            _apnsDeviceToken = nil; // XXX: this is not nice...
        }
        [self setState: kBackendReady];

        [self flushPendingMessages];
        [self flushPendingFiletransfers];
        [self updateRelationships];
        [self updatePresences];
        [self flushPendingInvites];
        [self updatePresence];
        [self updateKey];
    } else {
        [self stopAndRetry];
    }
}

- (NSString*) getPassword {
    NSString * password =  [[HTUserDefaults standardUserDefaults] valueForKey: kHTPassword];
    if (password == nil) {
        password = [[RSA sharedInstance] genRandomString:23];
        [[HTUserDefaults standardUserDefaults] setValue: password forKey: kHTPassword]; // TODO: put this is in the keychain
    }
    return password;
}

- (NSString*) getClientId {
    return [[HTUserDefaults standardUserDefaults] valueForKey: kHTClientId];
}

-(Contact *) getContactByClientId:(NSString *) theClientId {
    NSDictionary * vars = @{ @"clientId" : theClientId};    
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"ContactByClientId" substitutionVariables: vars];
    NSError *error;
    NSArray *contacts = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (contacts == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Contact * contact = nil;
    if (contacts.count > 0) {
        contact = contacts[0];
    } else {
        NSLog(@"ClientId %@ not in contacts", theClientId);
    }
    return contact;
}

- (void) acceptInvitation: (NSString*) token {
    if (_state == kBackendReady) {
        [self pairByToken: token];
    } else {
        if ( ! [self isInviteTokenInDatabase: token]) {
            Invite * invite =  (Invite*)[NSEntityDescription insertNewObjectForEntityForName: [Invite entityName] inManagedObjectContext: self.delegate.managedObjectContext];
            invite.token = token;
        }
    }
}

- (BOOL) isInviteTokenInDatabase: (NSString *) token {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * inviteEntity = [NSEntityDescription entityForName: [Invite entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [fetchRequest setEntity: inviteEntity];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.token == %@", token];
    [fetchRequest setPredicate: predicate];
    NSError *error;
    NSArray *invites = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (invites == nil) {
        NSLog(@"ERROR: isInviteTokenInDatabase: failed to execute fetch request: %@", error);
        abort();
    }
    return invites.count > 0;
}

- (void) gotAPNSDeviceToken: (NSString*) deviceToken {
    if (_state == kBackendReady) {
        [self registerApns: deviceToken];
    } else {
        _apnsDeviceToken = deviceToken;
    }
}

- (void) start: (BOOL) performRegistration {
    _performRegistration = performRegistration;
    [self setState: kBackendConnecting];
    [_serverConnection openWithURLRequest: [self urlRequest] protocols: @[kHXOProtocol]];
}

- (void) stop {
    [self setState: kBackendStopping];
    [_serverConnection close];
}

- (void) stopAndRetry {
    [self setState: kBackendStopped];
    [_serverConnection close];
}

- (void) reconnect {
    [self start: _performRegistration];
}

- (void) reconnectWitBackoff {
    NSLog(@"reconnecting in %f seconds", _backoffTime);
    if (_backoffTime == 0) {
        [self start: _performRegistration];
        _backoffTime = (double)rand() / RAND_MAX;
    } else {
        [NSTimer scheduledTimerWithTimeInterval: _backoffTime target: self selector: @selector(reconnect) userInfo: nil repeats: NO];
        _backoffTime = MIN(2 * _backoffTime, 10);
    }
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

- (void) flushPendingInvites {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * inviteEntity = [NSEntityDescription entityForName: [Invite entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [fetchRequest setEntity: inviteEntity];
    NSError *error;
    NSArray *invites = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (invites == nil) {
        NSLog(@"ERROR: flushPendingInvites: failed to execute fetch request: %@", error);
        abort();
    }
    for (Invite * invite in invites) {
        [self pairByToken: invite.token];
        [self.delegate.managedObjectContext deleteObject: invite];
    }
}

- (NSDate*) getLatestChangeDateFromRelationships {
    
    NSDate * latest = [NSDate dateWithTimeIntervalSince1970: 0];

    /*
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
    if (fetchResults == nil) {
        NSLog(@"ERROR: getLatestChangeDateFromRelationships: fetch request failed: %@", error);
        abort();
    }

    NSDate * latest = [[fetchResults lastObject] valueForKey:@"latestChange"];
    if (latest == nil) {
        latest = [NSDate dateWithTimeIntervalSince1970: 0];
    }
    */
    return latest;
}

- (void) updateRelationships {
    NSDate * latestChange = [self getLatestChangeDateFromRelationships];
    // NSLog(@"latest date %@", latestChange);
    [self getRelationships: latestChange relationshipHandler:^(NSArray * changedRelationships) {
        for (NSDictionary * relationshipDict in changedRelationships) {
            NSString * clientId = relationshipDict[@"otherClientId"];
            Contact * contact = [self getContactByClientId: clientId];
            if (contact == nil) {
                contact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:self.delegate.managedObjectContext];
                contact.clientId = clientId;
            }
            [contact updateWithDictionary: relationshipDict];
        }
    }];
}

- (void) updatePresences {
    NSDate * latestChange = [NSDate dateWithTimeIntervalSince1970:0];
    // NSLog(@"latest date %@", latestChange);
    [self getPresences: latestChange presenceHandler:^(NSArray * changedPresences) {
        for (id presence in changedPresences) {
            // NSLog(@"updatePresences presence=%@",presence);
            [self presenceUpdated:presence];
        }
    }];
}

- (void) fetchKeyForContact:(Contact *) theContact withKeyId:(NSString*) theId {
    [self getKey:theContact.clientId withId:theId keyHandler:^(NSDictionary * keyRecord) {
        if ([theId isEqualToString: keyRecord[@"keyId"]]) {
            theContact.publicKeyString = keyRecord[@"key"];
            theContact.publicKeyId = keyRecord[@"keyId"];
            // NSLog(@"Key for contact updated: %@", theContact);
            NSLog(@"Received new public key for contact: %@", theContact.nickName);
        } else {
            NSLog(@"ERROR: keynot updated response keyid mismatch for contact: %@", theContact);
        }
    }];
}

- (void) presenceUpdated:(NSDictionary *) thePresence {
    NSString * myClient = thePresence[@"clientId"];
    Contact * myContact = [self getContactByClientId:myClient];
    if (myContact == nil) {
        NSLog(@"clientId unknown, creating new contact for client: %@", myClient);
        myContact = [NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext: self.delegate.managedObjectContext];
        myContact.clientId = myClient;        
        myContact.relationshipState = kRelationStateNone;
        myContact.relationshipLastChanged = [NSDate dateWithTimeIntervalSince1970:0];
        myContact.avatarURL = @"";
    }
    
    if (myContact) {
        myContact.nickName = thePresence[@"clientName"];
        myContact.status = thePresence[@"clientStatus"];
        myContact.connectionStatus = thePresence[@"connectionStatus"];
        if (![myContact.publicKeyId isEqualToString: thePresence[@"keyId"]]) {
            // fetch key
            [self fetchKeyForContact: myContact withKeyId:thePresence[@"keyId"]];
        }
        if (![myContact.avatarURL isEqualToString: thePresence[@"avatarUrl"]]) {
            if ([thePresence[@"avatarUrl"] length]) {
                NSLog(@"presenceUpdated, downloading avatar from URL %@", thePresence[@"avatarUrl"]);
                NSURL * myURL = [NSURL URLWithString: thePresence[@"avatarUrl"]];
                NSError * myError = nil;
                NSData * myNewAvatar = [NSData dataWithContentsOfURL:myURL options:NSDataReadingUncached error:&myError];
                if (myNewAvatar != nil) {
                    NSLog(@"presenceUpdated, avatar downloaded");
                    myContact.avatar = myNewAvatar;
                    myContact.avatarURL = thePresence[@"avatarUrl"];
                } else {
                    NSLog(@"presenceUpdated, avatar download failed, error=%@", myError);
                }
            } else {
                // no avatar
                myContact.avatar = nil;
                myContact.avatarURL = @"";
            }
        }
        // NSLog(@"presenceUpdated, contact = %@", myContact);

    } else {
        NSLog(@"presenceUpdated: unknown clientId failed to create new contact for id: %@", myClient);
    }
}

#pragma mark - Attachment upload and download

- (void) flushPendingFiletransfers {
    [self uploadAvatarIfNeeded];
    [self flushPendingAttachmentUploads];
    [self flushPendingAttachmentDownloads];
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
        if ([attachment.contentSize longLongValue] <
            [[[HTUserDefaults standardUserDefaults] valueForKey:kHTAutoUploadLimit] longLongValue] ||
            [attachment.transferSize longLongValue] > 0)
        {
            [attachment upload];
        }
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
        if ([attachment.contentSize longLongValue] <
            [[[HTUserDefaults standardUserDefaults] valueForKey:kHTAutoDownloadLimit] longLongValue] ||
            [attachment.transferSize longLongValue] > 0)
        {
            [attachment download];
        }
    }
}

- (void) downloadFinished:(Attachment *)theAttachment {
    // NSLog(@"downloadFinished of %@", theAttachment);
    [self.delegate.managedObjectContext refreshObject: theAttachment.message mergeChanges:YES];
}


- (NSURL *) newUploadURL {
    // NSString * myURL = [kFileCacheDevelopmentURI stringByAppendingString:[NSString stringWithUUID]];
    NSString * myURL = [[[Environment sharedEnvironment] fileCacheURI] stringByAppendingString:[NSString stringWithUUID]];
    return [NSURL URLWithString: myURL];
}

- (NSString *) appendExpirationParams:(NSString*) theURL {
    NSDictionary *params = [NSDictionary dictionaryWithObject:[@(60*24*365*3) stringValue] forKey:@"expires_in"];
	theURL = [theURL stringByAppendingQuery:[params URLParams]];
    return theURL;
}

- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                             payload:(NSData *)payload
                             headers:(NSDictionary *)headers
{
    // hack, remove after better filestore comes online
    if ([method isEqualToString:@"PUT"]) {
        URLString = [self appendExpirationParams: URLString];
    }
    // end hack
	
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
    // NSLog(@"identify() clientId: %@", clientId);
    [_serverConnection invoke: @"identify" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (!success) {
            NSLog(@"identify(): got error: %@", responseOrError);
        }
        [self didFinishLogin: success];
    }];
}

- (void) generateId: (GenerateIdHandler) handler {
    [_serverConnection invoke: @"generateId" withParams: @[] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(responseOrError);
        } else {
            NSLog(@"deliveryRequest failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) srpRegisterWithVerifier: (NSString*) verifier andSalt: (NSString*) salt{
    [_serverConnection invoke: @"srpRegister" withParams: @[verifier, salt] onResponse: ^(id responseOrError, BOOL success) {
        [self didRegister: success];
    }];

}

- (void) srpPhase1WithClientId: (NSString*) clientId A: (NSString*) A andHandler: (SrpHanlder) handler {
    [_serverConnection invoke: @"srpPhase1" withParams: @[clientId, A] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(responseOrError);
        } else {
            NSLog(@"SRP Phase 1 failed");
            handler(nil);
        }
    }];
}

- (void) srpPhase2: (NSString*) M handler: (SrpHanlder) handler {
    [_serverConnection invoke: @"srpPhase2" withParams: @[M] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(responseOrError);
        } else {
            NSLog(@"SRP Phase 1 failed");
            handler(nil);
        }
    }];
}
- (void) deliveryRequest: (TalkMessage*) message withDeliveries: (NSArray*) deliveries {
    NSMutableDictionary * messageDict = [message rpcDictionary];
    NSMutableArray * deliveryDicts = [[NSMutableArray alloc] init];
    for (Delivery * delivery in deliveries) {
        [deliveryDicts addObject: [delivery rpcDictionary]];
    }
    // NSLog(@"deliveryRequest: %@", messageDict);
    [_serverConnection invoke: @"deliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"deliveryRequest() returned deliveries: %@", responseOrError);
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
    // NSLog(@"deliveryConfirm: %@", delivery);
    [_serverConnection invoke: @"deliveryConfirm" withParams: @[messageId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"deliveryConfirm() returned deliveries: %@", responseOrError);
            [delivery updateWithDictionary: responseOrError];
        } else {
            NSLog(@"deliveryConfirm() failed: %@", responseOrError);
        }
    }];
}

- (void) updatePresence: (NSString*) clientName withStatus: clientStatus withAvatar: (NSString*)avatarURL withKey: (NSData*)keyId {
    // NSLog(@"updatePresence: %@, %@, %@", clientName, clientStatus, avatarURL);
    NSDictionary *params = @{
                             @"clientName" : clientName,
                             @"clientStatus" : clientStatus,
                             @"avatarUrl" : avatarURL,
                             @"keyId" : [keyId hexadecimalString]
                             };
    [_serverConnection invoke: @"updatePresence" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"updatePresence() got result: %@", responseOrError);
        } else {
            NSLog(@"updatePresence() failed: %@", responseOrError);
        }
    }];
}

- (void) updatePresence {
    NSString * myAvatarURL = [self calcAvatarURL];
    NSString * myNickName = [[HTUserDefaults standardUserDefaults] objectForKey: kHTNickName];
   // NSString * myStatus = [[HTUserDefaults standardUserDefaults] objectForKey: kHTUserStatus];
    NSString * myStatus = @"I am.";
    
    NSData * myKeyBits = [[RSA sharedInstance] getPublicKeyBits];
    NSData * myKeyId = [[myKeyBits SHA256Hash] subdataWithRange:NSMakeRange(0, 8)];
    
    [self updatePresence: myNickName withStatus:myStatus withAvatar:myAvatarURL withKey: myKeyId];
}

- (void) profileUpdatedByUser:(NSNotification*)aNotification {
    if (_state == kBackendReady) {
        [self uploadAvatarIfNeeded];
        [self updatePresence];
    }
}


- (void) updateKey: (NSData*) publicKey {
    // NSLog(@"updateKey: %@", publicKey);
    NSData * myKeyId = [[publicKey SHA256Hash] subdataWithRange:NSMakeRange(0, 8)];
    NSDictionary *params = @{
                             @"key" :   [publicKey asBase64EncodedString], 
                             @"keyId" : [myKeyId hexadecimalString]
                             };
    [_serverConnection invoke: @"updateKey" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"updateKey() got result: %@", responseOrError);
        } else {
            NSLog(@"updateKey() failed: %@", responseOrError);
        }
    }];
}

- (void) updateKey {
    NSData * myKeyBits = [[RSA sharedInstance] getPublicKeyBits];
    [self updateKey: myKeyBits];
}

- (void) registerApns: (NSString*) token {
    // NSLog(@"registerApns: %@", token);
    [_serverConnection invoke: @"registerApns" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"registerApns(): got result: %@", responseOrError);
        } else {
            // TODO retry?
            NSLog(@"registerApns(): failed: %@", responseOrError);
        }
    }];
}

- (void) unregisterApns {
    // NSLog(@"unregisterApns:");
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
    // NSLog(@"generateToken:");
    [_serverConnection invoke: @"generateToken" withParams: @[purpose, @(seconds)] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"generateToken(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"generateToken(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) pairByToken: (NSString*) token {
    // NSLog(@"pairByToken:");
    [_serverConnection invoke: @"pairByToken" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        [self.delegate didPairWithStatus: [responseOrError boolValue]];
        if (success) {
            NSLog(@"pairByToken(): got result: %@", responseOrError);
            [self updatePresence];
            [self updatePresences];
        } else {
            NSLog(@"pairByToken(): failed: %@", responseOrError);
        }
    }];
}

- (void) getRelationships: (NSDate*) lastKnown relationshipHandler: (RelationshipHandler) handler {
    // NSLog(@"getRelationships:");
    NSNumber * lastKnownMillis = @([lastKnown timeIntervalSince1970] * 1000);
    [_serverConnection invoke: @"getRelationships" withParams: @[lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"getRelationships(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getRelationships(): failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

- (void) getPresences: (NSDate*) lastKnown presenceHandler: (PresenceHandler) handler {
    // NSLog(@"getPresences:");
    NSNumber * lastKnownMillis = @([lastKnown timeIntervalSince1970] * 1000);
    [_serverConnection invoke: @"getPresences" withParams: @[lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"getPresences(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getPresences(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) getKey: (NSString*)forClientId withId:(NSString*) keyId keyHandler:(PublicKeyHandler) handler {
    // NSLog(@"getKey:");

     [_serverConnection invoke: @"getKey" withParams: @[forClientId,keyId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"getKey(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getKey(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) updateUnreadMessageCount: (NSUInteger) count handler: (void (^)()) handler {
    // TODO: update message count
    NSLog(@"TODO: updateUnreadMessageCount ...");
    handler();
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

- (void) presenceUpdatedNotification: (NSArray*) params {
    //TODO: Error checking
    for (id presence in params) {
        // NSLog(@"updatePresences presence=%@",presence);
        [self presenceUpdated:presence];
    }
}

#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@", error);
    [self setState: kBackendStopped]; // XXX do we need/want a failed state?
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
    NSLog(@"webSocketDidOpen performRegistration: %d", _performRegistration);
    _backoffTime = 0.0;
    if (_performRegistration) {
        [self setState: kBackendRegistering];
        [self performRegistration];
    } else {
        [self startAuthentication];
    }
}

- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket didCloseWithCode %d reason: %@ clean: %d", code, reason, wasClean);
    BackendState oldState = _state;
    [self setState: kBackendStopped];
    if (oldState == kBackendStopping) {
        if ([self.delegate respondsToSelector:@selector(backendDidStop)]) {
            [self.delegate backendDidStop];
        }
    } else {
        [self reconnectWitBackoff];
    }
}

- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

#pragma mark - Avatar uploading

- (void) uploadAvatarIfNeeded {
    NSString * myDesiredURL = [self calcAvatarURL];
    NSString * myCurrentAvatarURL =[[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarURL];
    if (![myCurrentAvatarURL isEqualToString: myDesiredURL]) {
        if ([myDesiredURL length] != 0) {
            [self uploadAvatar: myDesiredURL];
        } else {
            [[HTUserDefaults standardUserDefaults] setObject: @"" forKey: kHTAvatarURL];
            [[HTUserDefaults standardUserDefaults] synchronize];
        }
    }
}

- (void) uploadAvatar: (NSString*)toURL {
    if (self.avatarUploadConnection != nil) {
        NSLog(@"avatar is still being uploaded");
        return;
    }
    NSData * myAvatarData = [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatar];
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
    NSData * myAvatarImmutableData = [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatar];
    if (myAvatarImmutableData == nil || [myAvatarImmutableData length] == 0) {
        return @"";
    }
    NSMutableData * myAvatarData = [NSMutableData dataWithData:myAvatarImmutableData];
    
    NSString * myClientID =[[HTUserDefaults standardUserDefaults] objectForKey: kHTClientId];
    [myAvatarData appendData:[myClientID dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSData * myHash = [myAvatarData SHA256Hash];
    NSString * myAvatarFileName = [myHash hexadecimalString];
    NSString * myURL = [[[Environment sharedEnvironment] fileCacheURI] stringByAppendingString:myAvatarFileName];
    return myURL;
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
            [self updatePresence];
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
