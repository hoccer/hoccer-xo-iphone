//
//  HoccerXOBackend.m
//  HoccerXO
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOBackend.h"

#import "JsonRpcWebSocket.h"
#import "HXOMessage.h"
#import "Delivery.h"
#import "Contact.h"
#import "Attachment.h"
#import "GroupMembership.h"
#import "Invite.h"
#import "AppDelegate.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "Environment.h"
#import "HXOUserDefaults.h"
#import "NSData+CommonCrypto.h"
#import "NSData+Base64.h"
#import "RSA.h"
#import "NSString+URLHelper.h"
#import "NSDictionary+CSURLParams.h"
#import "UserProfile.h"
#import "SoundEffectPlayer.h"
#import "SocketRocket/SRWebSocket.h"
#import "Group.h"
#import "Crypto.h"
#import "UserProfile.h"

#define DELIVERY_TRACE NO
#define GLITCH_TRACE NO
#define SECTION_TRACE NO

const NSString * const kHXOProtocol = @"com.hoccer.talk.v1";

typedef enum BackendStates {
    kBackendStopped,
    kBackendConnecting,
    kBackendRegistering,
    kBackendAuthenticating,
    kBackendReady,
    kBackendStopping
} BackendState;

@interface HXOBackend ()
{
    JsonRpcWebSocket * _serverConnection;
    BackendState       _state;
    double             _backoffTime;
    NSString *         _apnsDeviceToken;
    NSURLConnection *  _avatarUploadConnection;
    NSString *         _avatarUploadURL;
    NSString *         _avatarURL;
    NSInteger          _avatarBytesUploaded;
    NSInteger          _avatarBytesTotal;
    BOOL               _performRegistration;
    id                 _internetConnectionObserver;
    NSDate *           _lastReconnectAttempt;
}

- (void) identify;

@end

@implementation HXOBackend

- (id) initWithDelegate: (AppDelegate *) theAppDelegate {
    self = [super init];
    if (self != nil) {
        _backoffTime = 0.0;
        _state = kBackendStopped;
        _serverConnection = [[JsonRpcWebSocket alloc] init];
        _serverConnection.delegate = self;
        _apnsDeviceToken = nil;
        _lastReconnectAttempt = [NSDate dateWithTimeIntervalSince1970:0];
        [_serverConnection registerIncomingCall: @"incomingDelivery"    withSelector:@selector(incomingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"outgoingDelivery"    withSelector:@selector(outgoingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"pushNotRegistered"   withSelector:@selector(pushNotRegistered:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"presenceUpdated"     withSelector:@selector(presenceUpdatedNotification:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"relationshipUpdated" withSelector:@selector(relationshipUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"groupUpdated"        withSelector:@selector(groupUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"groupMemberUpdated"  withSelector:@selector(groupMemberUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"ping"                withSelector:@selector(ping) isNotification: NO];
        _delegate = theAppDelegate;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(profileUpdatedByUser:)
                                                     name:@"profileUpdatedByUser"
                                                   object:nil];
        
        _internetConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kGCNetworkReachabilityDidChangeNotification
                                                                          object:nil
                                                                           queue:[NSOperationQueue mainQueue]
                                                                      usingBlock:^(NSNotification *note) {
                                                                          
                                                                          GCNetworkReachabilityStatus status = [[note userInfo][kGCNetworkReachabilityStatusKey] integerValue];
                                                                          
                                                                          switch (status) {
                                                                              case GCNetworkReachabilityStatusNotReachable:
                                                                                  NSLog(@"No connection, disconnecting");
                                                                                  [self disconnect];
                                                                                  break;
                                                                              case GCNetworkReachabilityStatusWWAN:
                                                                                  NSLog(@"Reachable via WWAN");
                                                                                  [self reconnectIfNecessary];
                                                                                  break;
                                                                              case GCNetworkReachabilityStatusWiFi:
                                                                                  NSLog(@"Reachable via WiFi");
                                                                                  [self reconnectIfNecessary];
                                                                                  break;
                                                                                  
                                                                          }
                                                                      }];

    }
    return self;
}

+ (id) registerConnectionInfoObserverFor:(UIViewController*)controller {
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"connectionInfoChanged"
                                                                                    object:nil
                                                                                     queue:[NSOperationQueue mainQueue]
                                                                                usingBlock:^(NSNotification *note) {
                                                                                    
                                                                                    NSDictionary * info = [note userInfo];
                                                                                    if ([info[@"normal"] boolValue]) {
                                                                                        controller.navigationItem.prompt = nil;
                                                                                    } else {
                                                                                        controller.navigationItem.prompt = info[@"statusinfo"];
                                                                                    }
                                                                                }];
    return observer;
}

+ (void)broadcastConnectionInfo {
    [((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend updateConnectionStatusInfo];
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
    if (_state == kBackendReady) {
        _backoffTime = 0.0;
    }
    [self updateConnectionStatusInfo];
}

// notify everyone who is interested in displaying the status
- (void) updateConnectionStatusInfo {
    NSString * newInfo;
    BOOL normal = NO;
    if ([self.delegate.internetReachabilty isReachable]) {
        newInfo = [self stateString: _state];
        normal = (_state == kBackendReady) ;
    } else {
        newInfo = @"no internet";
    }
    //if (![self.connectionInfo isEqualToString:newInfo]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"connectionInfoChanged"
                                                            object:self
                                                          userInfo:@{ @"statusinfo":NSLocalizedString(newInfo, @"connection states"),
                                                                      @"normal":@(normal) }
         ];
    //}
}

- (void) saveServerTime:(NSDate *) theTime {
    self.latestKnownServerTime = theTime;
    self.latestKnownServerTimeAtClientTime = [NSDate date];
    self.latestKnownServerTimeOffset = [self.latestKnownServerTime timeIntervalSinceDate:self.latestKnownServerTimeAtClientTime];
    // offest is positive if server time is ahead of client time
    NSLog(@"Server time differs by %f secs. from our time, estimated server time = %@", self.latestKnownServerTimeOffset, [self estimatedServerTime]);
}

#define DEBUG_TIME_DAY (86400 * 1000)
#define DEBUG_TIME_OFFSET (0 * DEBUG_TIME_DAY)

- (NSDate*) estimatedServerTime {
    return [NSDate dateWithTimeIntervalSinceNow:self.latestKnownServerTimeOffset];
}

- (Attachment*) cloneAttachment:(const Attachment*) attachment whenReady:(AttachmentCompletionBlock)attachmentCompleted {
    Attachment * newAttachment = nil;
    if (attachment) {
        newAttachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: self.delegate.managedObjectContext];
        
        newAttachment.mediaType = attachment.mediaType;
        newAttachment.mimeType = attachment.mimeType;
        newAttachment.humanReadableFileName = attachment.humanReadableFileName;
        
        CompletionBlock completion  = ^(NSError *myerror) {
            attachmentCompleted(newAttachment, myerror);
        };
        
        if ([newAttachment.mediaType isEqualToString:@"image"]) {
            [newAttachment makeImageAttachment: attachment.localURL anOtherURL:attachment.assetURL image:nil withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"video"]) {
            [newAttachment makeVideoAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"audio"]) {
            [newAttachment makeAudioAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"vcard"]) {
            [newAttachment makeVcardAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"geolocation"]) {
            [newAttachment makeGeoLocationAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        }
    }
    return newAttachment;
}


// calls sendmessage after cloning the attachment
- (void) forwardMessage:(NSString *) text toContact: (Contact*) contact withAttachment: (const Attachment*) attachment {
    
    Attachment * newAttachment = nil;
    
    AttachmentCompletionBlock completion  = ^(Attachment * myAttachment, NSError *myerror) {
        if (myerror == nil) {
            [self sendMessage:text toContact:contact withAttachment:myAttachment];
        }
    };
    
    newAttachment = [self cloneAttachment:attachment whenReady:completion];
    if (newAttachment == nil) {
        // send message without attachment right now, we will not get a completion call here
        [self sendMessage: text toContact:contact withAttachment:nil];
    }
}

- (void) finishSendMessage:(HXOMessage*)message toContact:(Contact*)contact withDelivery:(Delivery*)delivery withAttachment:(Attachment*)attachment {
    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];
    
    if (_state == kBackendReady) {
        [self deliveryRequest: message withDeliveries: @[delivery]];
    }
    
    if (attachment != nil && attachment.state == kAttachmentWantsTransfer) {
        [attachment upload];
    }
    
    [self.delegate saveDatabase];
    [SoundEffectPlayer messageSent];
    
}

// TODO: contact should be an array of contacts
- (void) sendMessage:(NSString *) text toContact: (Contact*) contact withAttachment: (Attachment*) attachment {
    HXOMessage * message =  (HXOMessage*)[NSEntityDescription insertNewObjectForEntityForName: [HXOMessage entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    message.body = text;
    message.timeSent = [self estimatedServerTime]; // [NSDate date];
    message.contact = contact;
    message.timeAccepted = [self estimatedServerTime];
    message.isOutgoing = @YES;
    // message.timeSection = [contact sectionTimeForMessageTime: message.timeSent];
    message.messageId = @"";
    message.messageTag = [NSString stringWithUUID];

    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    delivery.receiver = contact;
    
    [message setupOutgoingEncryption];
    
    if (attachment != nil) {
        message.attachment = attachment;
        attachment.cipheredSize = [attachment calcCipheredSize];
        [self createFileForTransferWithSize:attachment.cipheredSize completionHandler:^(NSDictionary *urls) {
            if (urls) {
                NSLog(@"attachment urls=%@", urls);
                attachment.uploadURL = urls[@"uploadUrl"];
                attachment.remoteURL = urls[@"downloadUrl"];
                attachment.transferSize = @(0);
                attachment.cipherTransferSize = @(0);                
                // NSLog(@"sendMessage: message.attachment = %@", message.attachment);
                [self finishSendMessage:message toContact:contact withDelivery:delivery withAttachment:attachment];
            } else {
                NSLog(@"ERROR: Could not get attachment urls");
            }
        }];
        return;
    }
    [self finishSendMessage:message toContact:contact withDelivery:delivery withAttachment:attachment];
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
        if (messages.count != 1) {
            NSLog(@"ERROR: Database corrupted, duplicate messages with id %@ in database", messageDictionary[@"messageId"]);
            return;
        }
        HXOMessage * oldMessage = messages[0];
        Delivery * oldDelivery = [oldMessage.deliveries anyObject];
        if (GLITCH_TRACE) {NSLog(@"#GLITCH: receiveMessage: already have message with tag %@ id %@", oldMessage.messageTag, oldMessage.messageId);}
        if (DELIVERY_TRACE) {NSLog(@"receiveMessage: confirming duplicate message & delivery with state '%@' for tag %@ id %@",oldDelivery.state, oldMessage.messageTag, oldMessage.messageId);}
        [self deliveryConfirm: oldMessage.messageId withDelivery: oldDelivery];
        return;
    }
    if (![deliveryDictionary[@"keyCiphertext"] isKindOfClass:[NSString class]]) {
        NSLog(@"ERROR: receiveMessage: aborting received message without keyCiphertext, id= %@", vars[@"messageId"]);
        [self deliveryAbort:messageDictionary[@"messageId"] forClient:deliveryDictionary[@"receiverId"]];
        return;
    }

    if (![deliveryDictionary[@"keyId"] isEqualToString:[HXOBackend ownPublicKeyIdString]]) {
        NSLog(@"ERROR: receiveMessage: aborting received message with bad public keyId = %@, my keyId = %@", deliveryDictionary[@"keyId"],[HXOBackend ownPublicKeyIdString]);
       // - (void) deliveryAbort: (NSString*) theMessageId forClient:(NSString*) theReceiverClientId {
        [self deliveryAbort:messageDictionary[@"messageId"] forClient:deliveryDictionary[@"receiverId"]];
        return;
    }

    HXOMessage * message = [NSEntityDescription insertNewObjectForEntityForName: [HXOMessage entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    Delivery * delivery = [NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    
    Attachment * attachment = nil;
    if (messageDictionary[@"attachment"] != nil) {
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
    
    message.isOutgoing = @NO;
    message.isRead = @NO;
    message.timeReceived = [self estimatedServerTime];
    // message.timeSection = [contact sectionTimeForMessageTime: message.timeAccepted];
    message.contact = contact;
    contact.rememberedLastVisibleChatCell = nil; // make view to scroll to end when user enters chat
    [contact.messages addObject: message];
    [delivery updateWithDictionary: deliveryDictionary];
    [message updateWithDictionary: messageDictionary];

    contact.latestMessageTime = message.timeAccepted;
    
    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];

    
    if (attachment.state == kAttachmentWantsTransfer) {
        [self scheduleNewDownloadFor:attachment];
    }
    [self.delegate saveDatabase];
    if (DELIVERY_TRACE) {NSLog(@"receiveMessage: confirming new message & delivery with state '%@' for tag %@ id %@",delivery.state, delivery.message.messageTag, message.messageId);}
    [self deliveryConfirm: message.messageId withDelivery: delivery];
    [SoundEffectPlayer messageArrived];
}

- (void) performRegistration {
    // NSLog(@"performRegistration");
    GenerateIdHandler handler = ^(NSString * theId) {
        NSString * verifier = [[UserProfile sharedProfile] registerClientAndComputeVerifier: theId];
        [self srpRegisterWithVerifier: verifier andSalt: [UserProfile sharedProfile].salt];
    };
    [self generateId: handler];
}

- (void) didRegister: (BOOL) success {
    // NSLog(@"didRegister: %d", success);
    if (success) {
        _performRegistration = NO;
        [self startAuthentication];
    }
}

- (void) startAuthentication {
    [self setState: kBackendAuthenticating];
    NSString * A = [[UserProfile sharedProfile] startSrpAuthentication];
    [self srpPhase1WithClientId: [UserProfile sharedProfile].clientId A: A andHandler:^(NSString * challenge) {
        if (challenge == nil) {
            NSLog(@"SRP phase 1 failed");
        } else {
            NSString * M = [[UserProfile sharedProfile] processSrpChallenge: challenge];
            if (M == nil) {
                NSLog(@"SRP-6a safety check violation! Closing connection.");
                // possible tampering ... trigger reconnect by closing the socket
                [self stopAndRetry];
            } else {
                [self srpPhase2: M handler:^(NSString * HAMK) {
                    if (HAMK != nil) {
                        [self didFinishLogin: [[UserProfile sharedProfile] verifySrpSession: HAMK]];
                    } else {
                        [self didFinishLogin: NO];
                    }
                }];
            }
        }
    }];
}

- (void) didFinishLogin: (BOOL) authenticated{
    if (authenticated) {
        // NSLog(@"identify(): got result: %@", responseOrError);
        if (_apnsDeviceToken) {
            [self registerApns: _apnsDeviceToken];
            _apnsDeviceToken = nil; // XXX: this is not nice...
        }
        [self setState: kBackendReady];

        [self hello];
        
        [self flushPendingMessages];
        [self flushPendingFiletransfers];
        [self updateRelationships];
        [self updatePresences];
        [self flushPendingInvites];
        [self updatePresence];
        [self updateKey];
        [self getGroups];
    } else {
        [self stopAndRetry];
    }
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
        // NSLog(@"ClientId %@ not in contacts", theClientId);
    }
    return contact;
}

-(Group *) getGroupById:(NSString *) theGroupId {
    NSDictionary * vars = @{ @"clientId" : theGroupId};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"GroupByClientId" substitutionVariables: vars];
    NSError *error;
    NSArray *groups = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (groups == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Group * group = nil;
    if (groups.count > 0) {
        group = groups[0];
    } else {
        // NSLog(@"ClientId %@ not in contacts", theClientId);
    }
    return group;
}

-(Group *) getGroupById:(NSString *)theGroupId orByTag:(NSString *)theGroupTag {
    Group * group = [self getGroupById: theGroupId];
    if (group == nil) {
        group = [self getGroupByTag:theGroupTag];
        if (group == nil) {
            NSLog(@"INFO: getGroupById:orByTag: unknown group with id=%@ or tag %@",theGroupId,theGroupTag);
        }
    }
    return group;
}


-(Group *) getGroupByTag:(NSString *) theGroupTag {
    NSDictionary * vars = @{ @"groupTag" : theGroupTag};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"GroupByTag" substitutionVariables: vars];
    NSError *error;
    NSArray *groups = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (groups == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Group * group = nil;
    if (groups.count > 0) {
        group = groups[0];
    } else {
        // NSLog(@"theGroupTag %@ not in groups", theGroupTag);
    }
    return group;
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

// called by internetReachabilty Observer when internet connection is lost
- (void) disconnect {
    if (_state != kBackendStopped && _state != kBackendStopping) {
        [self stop];
    }
}

// called by internetReachabilty Observer when internet connection is lost
- (void) reconnectIfNecessary {
    if (_state == kBackendStopped ||_state == kBackendStopping) {
        [self reconnect];
    } else {
        NSLog(@"reconnectIfNecessary: not neccessary, state = %@", [self stateString:_state]);
    }
}

- (void) reconnect {
    if ([self.delegate.internetReachabilty isReachable]) {
        if ([[NSDate date] timeIntervalSinceDate:_lastReconnectAttempt] < 5.0) {
            [self reconnectWithBackoff];
        } else {
            [self start: _performRegistration];
        }
        _lastReconnectAttempt = [NSDate date];
    } else {
        NSLog(@"reconnect: no internet connection, backing off, state = %@", [self stateString:_state]);
        // we should not need to do that because we will be notified when the connection comes back
        // [self reconnectWithBackoff];
    }
}

- (void) reconnectWithBackoff {
    if (_backoffTime == 0) {
        _backoffTime = (double)rand() / RAND_MAX;
    } else {
        _backoffTime = MIN(2 * _backoffTime, 10);
    }
    NSLog(@"reconnecting in %f seconds", _backoffTime);
    [NSTimer scheduledTimerWithTimeInterval: _backoffTime target: self selector: @selector(reconnectIfNecessary) userInfo: nil repeats: NO];
}


- (NSURLRequest*) urlRequest {
    NSURL * url = [NSURL URLWithString: [[Environment sharedEnvironment] talkServer]];
    NSLog(@"using server: %@", [url absoluteString]);
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL: url];
    NSArray * certificates = [self certificates];
    if (certificates.count > 0) {
        request.SR_SSLPinnedCertificates = certificates;
    }
    return request;
}

@synthesize certificates = _certificates;
- (NSArray*) certificates {
    if (_certificates == nil) {
        NSArray * files = [[Environment sharedEnvironment] certificateFiles];
        NSMutableArray * certs = [[NSMutableArray alloc] initWithCapacity: files.count];
        for (NSString * file in files) {
            NSString * path = [[NSBundle mainBundle] pathForResource: file ofType:@"der"];
            NSData * certificateData = [[NSData alloc] initWithContentsOfFile: path];
            SecCertificateRef certificate = SecCertificateCreateWithData(nil, (__bridge CFDataRef)(certificateData));
            //NSLog(@"certificate: path: %@ cert: %@", path, certificate);
            [certs addObject: CFBridgingRelease(certificate)];
        }
        _certificates = [certs copy];
    }
    return _certificates;
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
    for (HXOMessage * message in pendingMessages) {
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

- (NSDate*) getLatestChangeDateForContactRelationships {
    return [self getLatestDateFromEntity:[Contact entityName] forKeyPath:@"relationshipLastChanged"];
}

- (NSDate*) getLatestChangeDateForContactPresence {
    return [self getLatestDateFromEntity:[Contact entityName] forKeyPath:@"presenceLastUpdated"];
}

- (NSDate*) getLatestChangeDateForGroups {
    return [self getLatestDateFromEntity:[Group entityName] forKeyPath:@"lastChanged"];
}


- (NSDate*) getLatestDateFromEntity:(NSString*) entityName forKeyPath:(NSString *) keyPath {
    // NSLog(@"getLatestDateFromEntity: %@ forKeyPath: %@", entityName, keyPath);

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: entityName inManagedObjectContext: self.delegate.managedObjectContext];
    [request setEntity:entity];
    [request setResultType:NSDictionaryResultType];
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:keyPath];
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
        NSLog(@"ERROR: getLatestDateFromEntity: %@ forKeyPath: %@ failed, error = %@", entityName, keyPath, error);
        abort();
    }
    
    NSDate * latest = [[fetchResults lastObject] valueForKey:@"latestChange"];
    if (latest == nil) {
        latest = [NSDate dateWithTimeIntervalSince1970: 0];
    }
    // NSLog(@"getLatestDateFromEntity: %@ forKeyPath: %@ latest = %@", entityName, keyPath, latest);
    return latest;
}

- (void) updateRelationships {
    NSDate * latestChange = [self getLatestChangeDateForContactRelationships];
    // NSDate * latestChange = [NSDate dateWithTimeIntervalSince1970:0]; // provoke update for testing
    // NSLog(@"latest date %@", latestChange);
    [self getRelationships: latestChange relationshipHandler:^(NSArray * changedRelationships) {
        for (NSDictionary * relationshipDict in changedRelationships) {
            [self updateRelationship: relationshipDict];
        }
    }];
}

+ (NSArray *) messagesByContactInInterval:(NSDictionary *) vars withTemplateName:(NSString*)name {
    AppDelegate* myDelegate = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    NSFetchRequest *fetchRequest = [myDelegate.managedObjectModel fetchRequestFromTemplateWithName:name substitutionVariables: vars];

    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeAccepted" ascending: YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSError *myError;
    NSArray *messages = [myDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&myError];

    return messages;
}

// messages >= sinceTime && < beforeTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalSinceTime:(NSDate *)sinceTime beforeTime:(NSDate*)beforeTime {
    NSDictionary * vars = @{ @"contact" : contact , @"sinceTime": sinceTime, @"beforeTime": beforeTime};
    return [HXOBackend messagesByContactInInterval:vars withTemplateName:@"MessagesByContactSinceTimeBeforeTime"];
}

// messages > afterTime && <= untilTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalAfterTime:(NSDate *)afterTime untilTime:(NSDate*)untilTime {
    NSDictionary * vars = @{ @"contact" : contact , @"afterTime": afterTime, @"untilTime": untilTime};
    return [HXOBackend messagesByContactInInterval:vars withTemplateName:@"MessagesByContactAfterTimeUntilTime"];
}

// messages >= sinceTime && <= untilTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalSinceTime:(NSDate *)sinceTime untilTime:(NSDate*)untilTime {
    NSDictionary * vars = @{ @"contact" : contact , @"sinceTime": sinceTime, @"untilTime": untilTime};
    return [HXOBackend messagesByContactInInterval:vars withTemplateName:@"MessagesByContactSinceTimeUntilTime"];
}

// messages > afterTime && < beforeTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalAfterTime:(NSDate *)afterTime beforeTime:(NSDate*)beforeTime {
    NSDictionary * vars = @{ @"contact" : contact , @"afterTime": afterTime, @"beforeTime": beforeTime};
    return [HXOBackend messagesByContactInInterval:vars withTemplateName:@"MessagesByContactAfterTimeBeforeTime"];
}

+ (void)adjustTimeSectionsForMessage:(HXOMessage*) message {
    const double sectionInterval = (2 * 60);
    //const double sectionInterval = 0.1;
    
    // check for previous messages and adjust message timeSection
    NSDate * sinceTime = [NSDate dateWithTimeInterval:-sectionInterval sinceDate:message.timeAccepted];
    NSArray * messagesBefore = [self messagesByContact:message.contact inIntervalSinceTime:sinceTime untilTime:message.timeAccepted];
    if ([messagesBefore count] > 1) {
        if ([((HXOMessage*)[messagesBefore objectAtIndex:0]) isEqual:message]) {
            // messagesBefore may have same timp stamp as message, and if message is first, pick next
            message.timeSection = ((HXOMessage*)[messagesBefore objectAtIndex:1]).timeSection;
        } else {
            message.timeSection = ((HXOMessage*)[messagesBefore objectAtIndex:0]).timeSection;
        }
        if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: other messages before (%@-%@) = %d",sinceTime,message.timeAccepted,[messagesBefore count]);}
    } else {
        // no other message before in interval, start new section
        message.timeSection = message.timeAccepted;
        if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: no other messages before in (%@-%@) count=%d, new section time%@", sinceTime,message.timeAccepted,[messagesBefore count],message.timeAccepted);}
    }
    // we have now processed all message with a time <= message.timeAccepted
    // adjust time section of messages after this section
    NSDate * untilTime = [NSDate dateWithTimeInterval:sectionInterval sinceDate:message.timeAccepted];
    
    NSArray * messagesAfter = [self messagesByContact:message.contact inIntervalAfterTime:message.timeAccepted untilTime:untilTime];
    int count = [messagesAfter count];
    if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: other messages after (%@-%@) = %d",message.timeAccepted,untilTime,count);}
    if (count > 0) {
        for (int i = 0; i < count; ++i) {
            HXOMessage * myMessage =  messagesAfter[i];
            myMessage.timeSection = message.timeSection;
            if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: adjusting item %d accepted %@ to timeSection %@",i, myMessage.timeAccepted,message.timeSection);}
        }
        if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: recursing for last message");}
        [self adjustTimeSectionsForMessage:messagesAfter.lastObject];
    }
}

- (void) updateRelationship: (NSDictionary*) relationshipDict {
    [self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
    
    NSString * clientId = relationshipDict[@"otherClientId"];
    Contact * contact = [self getContactByClientId: clientId];
    // XXX The server sends relationship updates with state 'none' even after depairing. We ignore those... 
    if ([relationshipDict[@"state"] isEqualToString: @"none"]) {
        return;
    }
    if (contact == nil) {
        contact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:self.delegate.managedObjectContext];
        contact.clientId = clientId;
    }
    // NSLog(@"relationship Dict: %@", relationshipDict);
    [contact updateWithDictionary: relationshipDict];
}

- (void) updatePresences {
    NSDate * latestChange = [self getLatestChangeDateForContactPresence];
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
        [self validateObject: keyRecord forEntity:@"RPC_TalkKey_in"];  // TODO: Handle Validation Error
        if (keyRecord != nil && [theId isEqualToString: keyRecord[@"keyId"]]) {
            theContact.publicKeyString = keyRecord[@"key"];
            theContact.publicKeyId = keyRecord[@"keyId"];
            // NSLog(@"Key for contact updated: %@", theContact);
            // NSLog(@"Received new public key for contact: %@", theContact.nickName);
        } else {
            NSLog(@"ERROR: keynot updated response keyid mismatch for contact: %@", theContact);
        }
    }];
}

- (void) presenceUpdated:(NSDictionary *) thePresence {
    NSString * myClient = thePresence[@"clientId"];
    Contact * myContact = [self getContactByClientId:myClient];
    if (myContact == nil) {
        // NSLog(@"clientId unknown, creating new contact for client: %@", myClient);
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
                // NSLog(@"presenceUpdated, downloading avatar from URL %@", thePresence[@"avatarUrl"]);
                NSURL * myURL = [NSURL URLWithString: thePresence[@"avatarUrl"]];
                NSError * myError = nil;
                NSData * myNewAvatar = [NSData dataWithContentsOfURL:myURL options:NSDataReadingUncached error:&myError];
                if (myNewAvatar != nil) {
                    // NSLog(@"presenceUpdated, avatar downloaded");
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
        myContact.presenceLastUpdatedMillis = thePresence[@"timestamp"];
        // NSLog(@"presenceUpdated, contact = %@", myContact);

    } else {
        NSLog(@"presenceUpdated: unknown clientId failed to create new contact for id: %@", myClient);
    }
}

#pragma mark - Group related rpc interfaces: notifications

//  void groupUpdated(TalkGroup group);
- (void) groupUpdated:(NSArray*) group_param {
    [self updateGroupHere: group_param[0]];
}

// void groupMemberUpdated(TalkGroupMember groupMember);
- (void) groupMemberUpdated:(NSArray*) groupMember_param {
    [self updateGroupMemberHere: groupMember_param[0]];
}

//public class TalkGroup {    
//    public String groupTag;
//    public String groupId;
//    public String groupName;
//    public String groupAvatarUrl;
//    public Date lastChanged;
//}



#pragma mark - Group related rpc interfaces: outgoing rpc calls

// TODO: better failure behavior using handler
- (void) createGroupWithHandler:(CreateGroupHandler)handler {
    Group * group = (Group*)[NSEntityDescription insertNewObjectForEntityForName: [Group entityName] inManagedObjectContext:self.delegate.managedObjectContext];
    group.type = [Group entityName];
    group.groupTag = [NSString stringWithUUID];
    group.myRole = @"admin";
    group.myState = @"accepted";
    group.groupKey = [AESCryptor random256BitKey];
    [self createGroup: group withHandler:handler];
}

// String createGroup(TalkGroup group);
- (void) createGroup:(Group *) group withHandler:(CreateGroupHandler)handler {
    NSMutableDictionary * groupDict = [group rpcDictionary];
    
    // [self validateObject: groupDict forEntity:@"RPC_Group_out"]; // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"createGroup" withParams: @[groupDict]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSString * groupId = (NSString*)responseOrError;
             group.clientId = groupId;
             handler(group);
             NSLog(@"createGroup() returned groupId: %@", responseOrError);
         } else {
             NSLog(@"createGroup() failed: %@", responseOrError);
             handler(nil);
         }
     }];
}

// get the list of all groups on the server I am a member of
//TalkGroup[] getGroups(Date lastKnown);
- (void) getGroups:(NSDate *)lastKnown groupsHandler:(GroupsHandler) handler {
    NSNumber * lastKnownMillis = [HXOBackend millisFromDate:lastKnown];
    [_serverConnection invoke: @"getGroups" withParams: @[lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"getGroups(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getGroups(): failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

- (void) getGroups {
    NSDate * latestChange = [self getLatestChangeDateForGroups];
    // NSDate * latestChange = [NSDate dateWithTimeIntervalSince1970:0]; // provoke update for testing
    // NSLog(@"latest date %@", latestChange);
    [self getGroups: latestChange groupsHandler:^(NSArray * changedGroups) {
        for (NSDictionary * groupDict in changedGroups) {
            [self updateGroupHere: groupDict];
        }
    }];
}

- (void) updateGroupHere: (NSDictionary*) groupDict {
    //[self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
        
    NSString * groupId = groupDict[@"groupId"];
    Group * group = [self getGroupById: groupId orByTag:groupDict[@"groupTag"]];

    if (group == nil) {
        group = (Group*)[NSEntityDescription insertNewObjectForEntityForName: [Group entityName] inManagedObjectContext:self.delegate.managedObjectContext];
        group.clientId = groupId;
        group.type = @"Group";
    }
    NSDate * lastKnown = group.lastChanged;
    
    // NSLog(@"relationship Dict: %@", relationshipDict);
    [group updateWithDictionary: groupDict];
    
    // update members
    [self getGroupMembers:group lastKnown:lastKnown];
}

// update a group on the server (as admin)
// void updateGroup(TalkGroup group);
- (void) updateGroup:(Group *) group {
    NSMutableDictionary * groupDict = [group rpcDictionary];
    
    // [self validateObject: groupDict forEntity:@"RPC_Group_out"]; // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"updateGroup" withParams: @[groupDict]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"updateGroup() ok: %@", responseOrError);
         } else {
             NSLog(@"updateGroup() failed: %@", responseOrError);
         }
     }];    
}

// void deleteGroup(String groupId);
- (void) deleteGroup:(Group *) group onDeletion:(GroupDeleted)deletionHandler {
    [_serverConnection invoke: @"deleteGroup" withParams: @[group.clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"deleteGroup() ok: got result: %@", responseOrError);
            deletionHandler(group);
        } else {
            NSLog(@"deleteGroup(): failed: %@", responseOrError);
            deletionHandler(nil);
        }
    }];
}

//TalkGroupMember[] getGroupMembers(String groupId, Date lastKnown);
- (void) getGroupMembers:(NSString *)groupId lastKnown:(NSDate*) lastKnown membershipsHandler:(MembershipsHandler)handler {
    NSNumber * lastKnownMillis = [HXOBackend millisFromDate:lastKnown];
    [_serverConnection invoke: @"getGroupMembers" withParams: @[groupId,lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"getGroups(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getGroups(): failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

- (void) getGroupMembers:(Group *)group lastKnown:(NSDate *)lastKnown {
    // NSDate * lastKnown = group.lastChanged;
    // NSDate * lastKnown = [NSDate dateWithTimeIntervalSince1970:0]; // provoke update for testing
    // NSLog(@"latest date %@", lastKnown);
    [self getGroupMembers: group.clientId lastKnown:lastKnown membershipsHandler:^(NSArray * changedMembers) {
        for (NSDictionary * memberDict in changedMembers) {
            [self updateGroupMemberHere: memberDict];
        }
    }];
}

//public class TalkGroupMember {
//    public static final String ROLE_NONE = "none";
//    public static final String ROLE_ADMIN = "admin";
//    public static final String ROLE_MEMBER = "member";
//
//    private String groupId;
//    private String clientId;
//    private String role;
//    private String state;
//    private String invitationSecret;
//    private String encryptedGroupKey;
//    private Date lastChanged;
//}

- (void) updateGroupMemberHere: (NSDictionary*) groupMemberDict {
    //[self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
    
    NSString * groupId = groupMemberDict[@"groupId"];
    Group * group = [self getGroupById: groupId];
    if (group == nil) {
        NSLog(@"ERROR: updateGroupMemberHere: unknown group with id=%@",groupId);
        return;
    }
        
    NSString * memberClientId = groupMemberDict[@"clientId"];

    Contact * memberContact = [self getContactByClientId:memberClientId];
    if (memberContact == nil  && ![memberClientId isEqualToString:[UserProfile sharedProfile].clientId]) {
        // create new Contact if it does not exist and is not own contact
        NSLog(@"updateGroupMemberHere: contact with clientId %@ unknown, creating",memberClientId);
        memberContact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:self.delegate.managedObjectContext];
        memberContact.clientId = memberClientId;
        //memberContact.nickName = @"BUG_WORKAROUND";
    }
    NSSet * theMemberSet = [group.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        if (memberContact != nil) {
            return [obj.contact.clientId isEqualToString: memberClientId];
        } else {
            // own contact
            return obj.contact == nil;
        }
    }];
    if ([theMemberSet count] > 1) {
        NSLog(@"ERROR: duplicate members in group %@ with id %@",groupId,memberClientId);
        return;
    }

    GroupMembership * myMember = nil;
    if ([theMemberSet count] == 0) {
        // create new member
        myMember = (GroupMembership*)[NSEntityDescription insertNewObjectForEntityForName: [GroupMembership entityName] inManagedObjectContext:self.delegate.managedObjectContext];
        myMember.contact = memberContact; // memberContact will be nil for own membership
        [group addMembersObject:myMember];
        myMember.group = group;
    } else {
        myMember = [theMemberSet anyObject];
    }
    
    // NSLog(@"groupMemberDict Dict: %@", groupMemberDict);
    [myMember updateWithDictionary: groupMemberDict];
    
    // now check if we have to update the encrypted group key
    if (memberContact != nil) { // not us
        if ([group.ownMemberShip.role isEqualToString:@"admin"]) {
            // we are admin
            if (myMember.cipheredGroupKey.length == 0 || ![myMember.cipheredGroupKey isEqualToData:myMember.distributedCipheredGroupKey]) {
                myMember.cipheredGroupKey = [myMember calcCipheredGroupKey];
                [self updateGroupKey:myMember onSuccess:^(GroupMembership *member) {
                    if (member) {
                        member.distributedCipheredGroupKey = member.cipheredGroupKey;
                    }
                }];
            }
        }
    }
}


//public class TalkGroupMember {
//    public static final String ROLE_NONE = "none";
//    public static final String ROLE_ADMIN = "admin";
//    public static final String ROLE_MEMBER = "member";
//
//    private String groupId;
//    private String clientId;
//    private String role;
//    private String state;
//    private String invitationSecret;
//    private String encryptedGroupKey;
//    private Date lastChanged;
//}

- (NSDictionary*) groupMemberKeys {
    return @{
             @"groupId": @"group.clientId",
             @"clientId": @"contact.clientId",
             @"role": @"role",
             @"state": @"state",
             @"lastChanged": @"lastChangedMillis",
             @"encryptedGroupKey": @"cipheredGroupKeyString"
             };
}

- (NSDictionary*) dictOfGroupMember:(GroupMembership*) member {
    return [HXOModel createDictionaryFromObject:member withKeys:[self groupMemberKeys]];
}

// void inviteGroupMember(String groupId, String clientId);
- (void) inviteGroupMember:(Contact *)contact toGroup:(Group*)group onDone:(GenericResultHandler)doneHandler{
    
    [_serverConnection invoke: @"inviteGroupMember" withParams: @[group.clientId,contact.clientId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"inviteGroupMember succeeded groupId: %@, clientId:%@",group.clientId,contact.clientId);
         } else {
             NSLog(@"inviteGroupMember() failed: %@", responseOrError);
         }
         doneHandler(success);
     }];
}

// void addGroupMember(TalkGroupMember member);
- (void) addGroupMember:(Contact *)contact toGroup:(Group*) group withRole:(NSString*)role {
    NSDictionary * myGroupMemberDict = @{
                                        @"groupId": group.clientId,
                                        @"clientId":contact.clientId,
                                        @"role": role,
                                        @"state": @"new",
                                        @"lastChanged": @(0)
                                        };
    [_serverConnection invoke: @"addGroupMember" withParams: @[myGroupMemberDict]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"addGroupMember succeeded groupId: %@, clientId:%@",group.clientId,contact.clientId);
         } else {
             NSLog(@"deliveryAcknowledge() failed: %@", responseOrError);
         }
     }];
}

// void removeGroupMember(TalkGroupMember member);
- (void) removeGroupMember:(GroupMembership *) member onDeletion:(GroupMemberDeleted)deletionHandler{

    [_serverConnection invoke: @"removeGroupMember" withParams: @[member.group.clientId,member.contact.clientId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"removeGroupMember succeeded groupId: %@, clientId:%@",member.group.clientId,member.contact.clientId);
             deletionHandler(member);
         } else {
             NSLog(@"removeGroupMember() failed: %@", responseOrError);
             deletionHandler(nil);
         }
     }];
}

// void updateGroupKey(String groupId, String clientId, String key);
- (void) updateGroupKey:(GroupMembership *)member onSuccess:(GroupMemberChanged)changedHandler{
    
    [_serverConnection invoke: @"updateGroupKey" withParams: @[member.group.clientId,member.contact.clientId,member.cipheredGroupKeyString]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             //NSLog(@"updateGroupKey succeeded groupId: %@, clientId:%@",member.group.clientId,member.contact.clientId);
             changedHandler(member);
         } else {
             NSLog(@"updateGroupKey() failed: %@", responseOrError);
             changedHandler(nil);
         }
     }];
}

// void updateGroupMember(TalkGroupMember member);
- (void) updateGroupMember:(GroupMembership *) member  {
    NSDictionary * myGroupMemberDict = [self dictOfGroupMember:member];
    [_serverConnection invoke: @"updateGroupMember" withParams: @[myGroupMemberDict]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"updateGroupMember succeeded groupId: %@, clientId:%@",member.group.clientId,member.contact.clientId);
         } else {
             NSLog(@"updateGroupMember() failed: %@", responseOrError);
         }
     }];    
}


#pragma mark - Attachment upload and download

- (void) flushPendingFiletransfers {
    [self uploadAvatarIfNeeded];
    [self flushPendingAttachmentUploads];
    [self flushPendingAttachmentDownloads];
}

- (void) flushPendingAttachmentUploads {
    // NSLog(@"flushPendingAttachmentUploads");
    // fetch all not yet transferred uploads
    NSDictionary * vars = @{ @"max_retries" : [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentUploadRetries]};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"AttachmentsNotUploaded" substitutionVariables: vars];
    // NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestTemplateForName:@"AllOutgoingAttachments"];
    NSError *error;
    NSArray *unfinishedAttachments = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (unfinishedAttachments == nil)
    {
        NSLog(@"Fetch request 'AttachmentsNotUploaded' failed: %@", error);
        abort();
    }
    NSLog(@"flushPendingAttachmentUploads found %d unfinished uploads", [unfinishedAttachments count]);
    for (Attachment * attachment in unfinishedAttachments) {
        AttachmentState attachmentState = attachment.state;
        if (attachmentState == kAttachmentWantsTransfer ||
            attachmentState == kAttachmentUploadIncomplete)
        {
            [attachment upload];
        }
    }
}

- (void) flushPendingAttachmentDownloads {
    // NSLog(@"flushPendingAttachmentDownloads");
    // fetch all not yet transferred uploads
    NSDictionary * vars = @{ @"max_retries" : [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentDownloadRetries]};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"AttachmentsNotDownloaded" substitutionVariables: vars];
    
    //NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestTemplateForName:@"AllOutgoingAttachments"];
    NSError *error;
    NSArray *unfinishedAttachments = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (unfinishedAttachments == nil)
    {
        NSLog(@"Fetch request 'AttachmentsNotDownloaded' failed: %@", error);
        abort();
    }
    NSLog(@"flushPendingAttachmentDownloads found %d unfinished downloads", [unfinishedAttachments count]);
    for (Attachment * attachment in unfinishedAttachments) {
        AttachmentState attachmentState = attachment.state;
        if (attachmentState == kAttachmentWantsTransfer ||
            attachmentState == kAttachmentDownloadIncomplete)
        {
            [attachment download];
        }
    }
}


- (void) downloadFinished:(Attachment *)theAttachment {
    // NSLog(@"downloadFinished of %@", theAttachment);
    [self.delegate.managedObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
}

- (void) uploadFinished:(Attachment *)theAttachment {
    // NSLog(@"uploadFinished of %@", theAttachment);
    [self.delegate.managedObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
}

- (void) downloadFailed:(Attachment *)theAttachment {
    // NSLog(@"downloadFailed of %@", theAttachment);
    theAttachment.transferFailures = theAttachment.transferFailures + 1;
    [self.delegate.managedObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self scheduleNewDownloadFor:theAttachment];
}

- (void) uploadFailed:(Attachment *)theAttachment {
    // NSLog(@"uploadFinished of %@", theAttachment);
    theAttachment.transferFailures = theAttachment.transferFailures + 1;
    [self.delegate.managedObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self scheduleNewUploadFor:theAttachment];
}

- (double) transferRetryTimeFor:(Attachment *)theAttachment {
    double randomFactor = (double)arc4random()/(double)0xffffffff;
    double retryTime = (2.0 + randomFactor) * (theAttachment.transferFailures * theAttachment.transferFailures + 1);
    //double retryTime = 2.0;
    return retryTime;
}

-(void) scheduleNewTransferFor:(Attachment *)theAttachment inSecs:(double)retryTime withSelector:(SEL)theTransferSelector withErrorKey: (NSString*) errorKey {
    if (theAttachment.transferRetryTimer != nil) {
        // NSLog(@"scheduleNewTransferFor:%@ invalidating timer for transfer in %f secs", theAttachment.remoteURL, [[theAttachment.transferRetryTimer fireDate] timeIntervalSinceNow]);
        [theAttachment.transferRetryTimer invalidate];
        theAttachment.transferRetryTimer = nil;
    }
    if (theAttachment.state == kAttachmentUploadIncomplete ||
        theAttachment.state == kAttachmentDownloadIncomplete ||
        theAttachment.state == kAttachmentWantsTransfer) {
        NSLog(@"scheduleNewTransferFor:%@ failures = %i, retry in = %f secs",[theAttachment.message.isOutgoing isEqual:@(YES)]?theAttachment.uploadURL: theAttachment.remoteURL, theAttachment.transferFailures, retryTime);
        theAttachment.transferRetryTimer = [NSTimer scheduledTimerWithTimeInterval:retryTime
                                                                            target:theAttachment
                                                                          selector: theTransferSelector
                                                                          userInfo:nil
                                                                           repeats:NO];
    } else  if (theAttachment.state == kAttachmentTransfersExhausted) {
        NSString * titleKey = [NSString stringWithFormat: @"%@_title", errorKey];
        NSString * messageKey = [NSString stringWithFormat: @"%@_message", errorKey];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(titleKey, nil)
                                                         message: NSLocalizedString(messageKey, nil)
                                                        delegate: nil
                                               cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                               otherButtonTitles: nil];
        [alert show];
        NSLog(@"scheduleTransferRetryFor:%@ max retry count reached, failures = %i, no transfer scheduled",
              [theAttachment.message.isOutgoing isEqual:@(YES)]?theAttachment.uploadURL: theAttachment.remoteURL, theAttachment.transferFailures);
    }
}


-(void) scheduleNewDownloadFor:(Attachment *)theAttachment {
    [self scheduleNewTransferFor:theAttachment
                          inSecs:[self transferRetryTimeFor:theAttachment]
                    withSelector:@selector(downloadOnTimer:)
                    withErrorKey:@"attachment_download_failed"];
}

-(void) scheduleNewUploadFor:(Attachment *)theAttachment {
    [self scheduleNewTransferFor:theAttachment
                          inSecs:[self transferRetryTimeFor:theAttachment]
                    withSelector:@selector(uploadOnTimer:)
                    withErrorKey:@"attachment_upload_failed"];
}

//- (NSDictionary *)getNewTransferUrlsFor:(NSArray*)receiverIds {
//    NSString * myUUID = [NSString stringWithUUID];
//    NSString * myBaseURL = [[Environment sharedEnvironment] fileCacheURI];
//    NSString * myUploadUrl = [[myBaseURL stringByAppendingString:@"upload/"] stringByAppendingString:myUUID];
//    NSString * myDownloadUrl = [[myBaseURL stringByAppendingString:@"download/"] stringByAppendingString:myUUID];
//    NSDictionary * myUrls = @{@"upload":myUploadUrl, @"download": myDownloadUrl};
//    return myUrls;
//};

//- (NSURL *) newUploadURL {
//    NSString * myURL = [[[Environment sharedEnvironment] fileCacheURI] stringByAppendingString:[NSString stringWithUUID]];
//    return [NSURL URLWithString: myURL];
//}

- (NSString *) appendExpirationParams:(NSString*) theURL {
    NSDictionary *params = [NSDictionary dictionaryWithObject:[@(60*24*365*3) stringValue] forKey:@"expires_in"];
	theURL = [theURL stringByAppendingQuery:[params URLParams]];
    return theURL;
}

- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                             payloadData:(NSData *)payload
                             payloadStream:(NSInputStream*)stream
                             headers:(NSDictionary *)headers
{
    // hack, remove after better filestore comes online
    if ([method isEqualToString:@"PUT"]) {
        URLString = [self appendExpirationParams: URLString];
    }
    // end hack
	
    // NSLog(@"httpRequest method: %@ url: %@", method, URLString);
    NSURL *url = [NSURL URLWithString:URLString];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	
	[request addValue:self.delegate.userAgent forHTTPHeaderField:@"User-Agent"];
	for (NSString *key in headers) {
		[request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
	}
    
	[request setHTTPMethod:method];
    if (payload != nil) {
        [request setHTTPBody:payload];
    }
    if (stream != nil) {
        [request setHTTPBodyStream:stream];
    }
	[request setTimeoutInterval:60];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    return request;
}

#pragma mark - Outgoing RPC Calls

- (void) identify {
    NSString * clientId = [UserProfile sharedProfile].clientId;
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

- (void) srpRegisterWithVerifier: (NSString*) verifier andSalt: (NSString*) salt {
    //NSLog(@"srpRegisterWithVerifier: %@ andSalt: %@", verifier, salt);
    [_serverConnection invoke: @"srpRegister" withParams: @[verifier, salt] onResponse: ^(id responseOrError, BOOL success) {
        if ( ! success) {
            NSLog(@"ERROR - registration failed: %@", responseOrError);
        }
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
            NSLog(@"SRP Phase 2 failed");
            handler(nil);
            //abort();
        }
    }];
}

- (void) hello:(NSNumber*) clientTime  handler:(HelloHandler) handler {
    // NSLog(@"hello: %@", clientTime);
    NSDictionary *params = @{
                             @"clientTime" : clientTime
                             };
    [_serverConnection invoke: @"hello" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(responseOrError);
        } else {
            NSLog(@"hello() failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) hello {
    NSNumber * clientTime = [HXOBackend millisFromDate:[NSDate date]];
    [self hello:clientTime handler:^(NSDictionary * result) {
        if (result != nil) {
            [self saveServerTime:[HXOBackend dateFromMillis:result[@"serverTime"]]];
        }
    }];
}

+ (NSNumber*) millisFromDate:(NSDate *) date {
    if (date == nil) {
        return [NSNumber numberWithDouble:0];
    }
    return [NSNumber numberWithLongLong:[date timeIntervalSince1970]*1000+DEBUG_TIME_OFFSET];
}

+ (NSDate*) dateFromMillis:(NSNumber*) milliSecondsSince1970 {
    return [NSDate dateWithTimeIntervalSince1970: ([milliSecondsSince1970 doubleValue]-DEBUG_TIME_OFFSET) / 1000.0 ];
}

// Regex for UUID:
// [0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}

- (BOOL) validateObject:(id)objectToValidate forEntity:(NSString*)entityName error:(out NSError **) myError {
    // NSLog(@">>> Validating Object: %@", objectToValidate);
    if (objectToValidate == nil) {
        NSString * myDescription = [NSString stringWithFormat:@"validateObject: objectToValidate is nil"];
        *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9900 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return NO;        
    }
    NSDictionary * myEntities = [_delegate.rpcObjectModel entitiesByName];
    if (myEntities == nil) {
        NSString * myDescription = [NSString stringWithFormat:@"validateObject: cant get Entities for rpcObjectModel"];
        *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9901 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return NO;
    }
    NSEntityDescription * myEntity = myEntities[entityName];
    if (myEntity == nil) {
        NSString * myDescription = [NSString stringWithFormat:@"validateObject: cant find Entity '%@'", entityName];
        *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9902 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return NO;
    }
    NSManagedObject * myObject = [[NSManagedObject alloc] initWithEntity:myEntity insertIntoManagedObjectContext:nil];
    if (myObject == nil) {
        NSString * myDescription = [NSString stringWithFormat:@"validateObject: cant init object for Entity '%@'", entityName];
        *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9903 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return NO;
    }
#if VALIDATOR_DEBUG
    NSDictionary * myAttributes = [myEntity attributesByName];
    for (id attribute in myAttributes) {
        NSLog(@"entity has attr %@, decr %@", attribute, [myAttributes[attribute] attributeValueClassName]);
    }
#endif
    NSError * myOtherError = nil;
    for (id property in objectToValidate) {
        id myValue = objectToValidate[property];
        if (myValue == nil) {
            NSLog(@"WARNING: objectToValidate property %@ is nil",property);
        }
        if (![myObject validateValue:&myValue forKey:property error:&myOtherError]) {
            NSString * myDescription = [NSString stringWithFormat:@"validateObject: Entity '%@', property '%@', value fails validation: %@, reason: %@", entityName, property, myValue, myOtherError];
            *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9904 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            return NO;
        };
        @try {
            // NSLog(@"try validating property %@",property);
            [myObject setValue: myValue forKeyPath: property];
        }
        @catch (NSException* ex) {
            // NSLog(@"!!!! Exception: %@\n", ex);
            NSString * myDescription = [NSString stringWithFormat:@"validateObject: Entity '%@', property '%@', value setting failed: %@, reason: %@", entityName, property, myValue, ex];
            *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9905 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            return NO;
        }
    }
    // NSLog(@"=== Validating properties done");
    if (![myObject validateForUpdate:myError]) {
        NSString * myDescription = [NSString stringWithFormat:@"validateObject: Entity '%@', full object validation failed, reason: %@", entityName, *myError];
        *myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9906 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return NO;
    }
    // NSLog(@"! Validating Object for entity '%@' passed", entityName);
    return YES;
}

- (BOOL) validateObject:(id)objectToValidate forEntity:(NSString*)entityName {
    NSError * myError = nil;
    BOOL myResult = [self validateObject:objectToValidate forEntity:entityName error:&myError];
    if (!myResult) {
        NSLog(@"ERROR: %@", myError);
    }
    return myResult;
}



// client calls this method to send a Talkmessage along with the intended recipients in the deliveries array
// the return result contains an array with updated deliveries
- (void) deliveryRequest: (HXOMessage*) message withDeliveries: (NSArray*) deliveries {
    NSMutableDictionary * messageDict = [message rpcDictionary];
    NSMutableArray * deliveryDicts = [[NSMutableArray alloc] init];
    for (Delivery * delivery in deliveries) {
        [deliveryDicts addObject: [delivery rpcDictionary]];
    }
    // validate
    for (NSDictionary * d in deliveryDicts) {
        [self validateObject: d forEntity:@"RPC_TalkDelivery_out"];  // TODO: Handle Validation Error
    }
    
    [self validateObject: messageDict forEntity:@"RPC_TalkMessage_out"]; // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"deliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"deliveryRequest() returned deliveries: %@", responseOrError);
            NSArray * updatedDeliveryDicts = (NSArray*)responseOrError;
            int i = 0;
            for (Delivery * delivery in deliveries) {
                [self validateObject: updatedDeliveryDicts[i] forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
                if (DELIVERY_TRACE) {NSLog(@"deliveryRequest result: Delivery state '%@'->'%@' for messageTag %@ id %@",delivery.state, updatedDeliveryDicts[i][@"state"], updatedDeliveryDicts[i][@"messageTag"],updatedDeliveryDicts[i][@"messageId"] );}
                [delivery updateWithDictionary: updatedDeliveryDicts[i++]];
                delivery.receiver.latestMessageTime = message.timeAccepted;
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
            [self validateObject: responseOrError forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
            if (DELIVERY_TRACE) {NSLog(@"deliveryConfirm result: state %@->%@ for messageTag %@",delivery.state, responseOrError[@"state"], delivery.message.messageTag);}
            if ([delivery.state isEqualToString: responseOrError[@"state"]]) {
                if (GLITCH_TRACE) {NSLog(@"#GLITCH: deliveryConfirm result: state unchanged %@->%@ for messageTag %@",delivery.state, responseOrError[@"state"], delivery.message.messageTag);}
            }
            [delivery updateWithDictionary: responseOrError];
            [self.delegate saveDatabase];
        } else {
            NSLog(@"deliveryConfirm() failed: %@", responseOrError);
        }
    }];
}

- (void) deliveryAcknowledge: (Delivery*) delivery {
    // NSLog(@"deliveryAcknowledge: %@", delivery);
    
    [_serverConnection invoke: @"deliveryAcknowledge" withParams: @[delivery.message.messageId, delivery.receiver.clientId]
                   onResponse: ^(id responseOrError, BOOL success)
    {
        if (success) {
            // NSLog(@"deliveryAcknowledge() returned delivery: %@", responseOrError);
            [self validateObject: responseOrError forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
            
            NSString * oldState = [delivery.state copy];
            [delivery updateWithDictionary: responseOrError];
            
            // TODO: fix acknowledge storm on server, server should return "confirmed" status
            if (![delivery.state isEqualToString:@"confirmed"]) {
                NSLog(@"#WARNING: Wrong Server Response: deliveryAcknowledge result should be state ‘confirmed' but is '%@', overriding own state to 'confirmed'", delivery.state);
                delivery.state = @"confirmed";
            } else {
                if (DELIVERY_TRACE) {NSLog(@"deliveryAcknowledge result: state %@->%@ for messageTag %@ id %@",oldState, delivery.state, delivery.message.messageTag,delivery.message.messageId);}
                if ([oldState isEqualToString: delivery.state]) {
                    if (GLITCH_TRACE) {NSLog(@"#GLITCH: deliveryAcknowledge result: duplicate state change %@->%@ for messageTag %@ id %@",oldState, delivery.state, delivery.message.messageTag,delivery.message.messageId);}
                }
            }
            // NSLog(@"deliveryAcknowledge:response was: %@",responseOrError);
            
            [self.delegate saveDatabase];
            [self.delegate.managedObjectContext refreshObject: delivery.message mergeChanges: YES];
        } else {
            NSLog(@"deliveryAcknowledge() failed: %@", responseOrError);
        }
    }];
}

- (void) deliveryAbort: (NSString*) theMessageId forClient:(NSString*) theReceiverClientId {
    // NSLog(@"deliveryAbort: %@", delivery);
    [_serverConnection invoke: @"deliveryAbort" withParams: @[theMessageId, theReceiverClientId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             // NSLog(@"deliveryAbort() returned delivery: %@", responseOrError);
         } else {
             NSLog(@"deliveryAbort() failed: %@", responseOrError);
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
    [self validateObject: params forEntity:@"RPC_TalkPresence_out"];  // TODO: Handle Validation Error

    [_serverConnection invoke: @"updatePresence" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"updatePresence() got result: %@", responseOrError);
        } else {
            NSLog(@"updatePresence() failed: %@", responseOrError);
        }
    }];
}

- (void) updatePresence {
    NSString * myAvatarURL = [UserProfile sharedProfile].avatarURL;
    if (myAvatarURL == nil) {
        myAvatarURL = @"";
    }
    NSString * myNickName = [UserProfile sharedProfile].nickName;
   // NSString * myStatus = [UserProfile sharedProfile].status;
    NSString * myStatus = @"I am.";
    
    if (myNickName == nil) {
        myNickName = @"";
    }
    [self updatePresence: myNickName withStatus:myStatus withAvatar:myAvatarURL withKey: [HXOBackend ownPublicKeyId]];
}

- (void) profileUpdatedByUser:(NSNotification*)aNotification {
    if (_state == kBackendReady) {
        [self uploadAvatarIfNeeded];
        [self updatePresence];
        [self updateKey];
    }
}

+ (NSString *) ownPublicKeyIdString {
    return [self keyIdString:[self ownPublicKeyId]];
}

+ (NSData *) ownPublicKeyId {
    NSData * myKeyBits = [self ownPublicKey];
    return [HXOBackend calcKeyId:myKeyBits];
}

+ (NSData *) ownPublicKey {
    return[[RSA sharedInstance] getPublicKeyBits];
}

+ (NSData *) calcKeyId:(NSData *) myKeyBits {
    NSData * myKeyId = [[myKeyBits SHA256Hash] subdataWithRange:NSMakeRange(0, 8)];
    return myKeyId;
}

+ (NSString *) keyIdString:(NSData *) myKeyId {
    return [myKeyId hexadecimalString];
}

- (void) updateKey: (NSData*) publicKey {
    // NSLog(@"updateKey: %@", publicKey);
    NSData * myKeyId = [HXOBackend calcKeyId:publicKey];
    NSDictionary *params = @{
                             @"key" :   [publicKey asBase64EncodedString], 
                             @"keyId" : [myKeyId hexadecimalString]
                             };
    [self validateObject: params forEntity:@"RPC_TalkKey_out"];  // TODO: Handle Validation Error

    [_serverConnection invoke: @"updateKey" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"updateKey() got result: %@", responseOrError);
        } else {
            NSLog(@"updateKey() failed: %@", responseOrError);
        }
    }];
}

- (void) updateKey {
    NSData * myKeyBits = [HXOBackend ownPublicKey];
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
            // NSLog(@"unregisterApns(): got result: %@", responseOrError);
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
            // NSLog(@"generateToken(): got result: %@", responseOrError);
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
            // NSLog(@"pairByToken(): got result: %@", responseOrError);
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
        if (success && [responseOrError isKindOfClass: [NSDictionary class]]) {
            // NSLog(@"getKey(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getKey(): failed - response: %@", responseOrError);
            handler(nil);
        }
    }];
}

//FileHandles createFileForStorage(int contentLength);
- (void) createFileForStorageWithSize:(NSNumber*) size completionHandler:(FileURLRequestHandler) handler {
    // NSLog(@"createFileForStorageWithSize:");
    
    [_serverConnection invoke: @"createFileForStorage" withParams: @[size] onResponse: ^(id responseOrError, BOOL success) {
        if (success && [responseOrError isKindOfClass: [NSDictionary class]]) {
            NSLog(@"createFileForStorageWithSize(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"createFileForStorageWithSize(): failed - response: %@", responseOrError);
            handler(nil);
        }
    }];
}

//FileHandles createFileForTransfer(int contentLength);
- (void) createFileForTransferWithSize:(NSNumber*) size completionHandler:(FileURLRequestHandler) handler {
    // NSLog(@"createFileForStorageWithSize:");
    
    [_serverConnection invoke: @"createFileForStorage" withParams: @[size] onResponse: ^(id responseOrError, BOOL success) {
        if (success && [responseOrError isKindOfClass: [NSDictionary class]]) {
            NSLog(@"createFileForTransferWithSize(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"createFileForTransferWithSize(): failed - response: %@", responseOrError);
            handler(nil);
        }
    }];
}


- (void) hintApnsUnreadMessage: (NSUInteger) count handler: (GenericResultHandler) handler {
    //NSLog(@"hintApnsUnreadMessage");
    [_serverConnection invoke: @"hintApnsUnreadMessage" withParams: @[@(count)] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];

}

- (void) blockClient: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"blockClient");
    [_serverConnection invoke: @"blockClient" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}

- (void) unblockClient: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"unblockClient");
    [_serverConnection invoke: @"unblockClient" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}

- (void) depairClient: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"unblockClient");
    [_serverConnection invoke: @"depairClient" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
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

    [self validateObject: messageDict forEntity:@"RPC_TalkMessage_in"];  // TODO: Handle Validation Error
    [self validateObject: deliveryDict forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error

    [self receiveMessage: messageDict withDelivery: deliveryDict];
}

// utility function to avoid code duplication
-(Delivery *) getDeliveryByMessageTagAndReceiverId:(NSString *) theMessageTag withReceiver: (NSString *) theReceiverId  {
    NSDictionary * vars = @{ @"messageTag" : theMessageTag,
                             @"receiverId" : theReceiverId};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"DeliveryByMessageTagAndReceiverId" substitutionVariables: vars];
    NSError *error;
    NSArray *deliveries = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"DeliveryByMessageTagAndReceiverId: Fetch request failed: %@", error);
        abort();
    }
    Delivery * delivery = nil;
    if (deliveries.count > 0) {
        delivery = deliveries[0];
        if (deliveries.count > 1) {
            NSLog(@"WARNING: Multiple deliveries with MessageTag %@ for receiver %@ found", theMessageTag, theReceiverId);
        }
    } else {
        NSLog(@"Delivery with MessageTag %@ for receiver %@ not in deliveries", theMessageTag, theReceiverId);
    }
    return delivery;
}


// called by server to notify us about status changes of outgoing deliveries we made
- (void) outgoingDelivery: (NSArray*) params {
    if (params.count != 1) {
        NSLog(@"outgoingDelivery: requires an array of one parameters (delivery), but got %d parameters.", params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"outgoingDelivery: argument is not a valid object");
        return;
    }
    NSDictionary * deliveryDict = params[0];
    // NSLog(@"outgoingDelivery() called, dict = %@", deliveryDict);

    [self validateObject: deliveryDict forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
    
    NSString * myMessageTag = deliveryDict[@"messageTag"];
    NSString * myReceiverId = deliveryDict[@"receiverId"];
    
    Delivery * myDelivery = [self getDeliveryByMessageTagAndReceiverId:myMessageTag withReceiver: myReceiverId];
    if (myDelivery != nil) {
        // TODO: server should not send outgoingDelivery-changes for confirmed object, we just won't answer them for now to avoid ack-storms
        if ([myDelivery.state isEqualToString:@"confirmed"]) {
            // we have already acknowledged and received confirmation for ack, so server should have shut up and never sent us this in the first time
            NSLog(@"Bad server behavior: outgoingDelivery Notification received for already confirmed delivery msg-id: %@", deliveryDict[@"messageId"]);
            [self deliveryAcknowledge: myDelivery];
            return;
        }
        
        if (DELIVERY_TRACE) {NSLog(@"outgoingDelivery Notification: Delivery state '%@'->'%@' for messageTag %@ id %@",myDelivery.state, deliveryDict[@"state"], myMessageTag, deliveryDict[@"messageId"]);}
        
        if ([myDelivery.state isEqualToString:deliveryDict[@"state"]]) {
            if (GLITCH_TRACE) {NSLog(@"#GLITCH: Duplicate outgoingDelivery Notification: Delivery state for messageTag %@ id %@ was already %@, timeStamps: old %@ new %@", myMessageTag, deliveryDict[@"messageId"], myDelivery.state, myDelivery.timeChangedMillis, deliveryDict[@"timeChanged"]);}
        }
        [myDelivery updateWithDictionary: deliveryDict];
        [self.delegate.managedObjectContext refreshObject: myDelivery.message mergeChanges: YES];
        
        // NSLog(@"Delivery state for messageTag %@ receiver %@ changed to %@", myMessageTag, myReceiverId, myDelivery.state);
        
        if ([myDelivery.state isEqualToString:@"delivered"] ) {
            [SoundEffectPlayer messageDelivered];
        } else {
            NSLog(@"#WARNING: We acknowledged Delivery state ‘%@‘ for messageTag %@ ", myDelivery.state, myMessageTag);
        }
        
        // TODO: check if acknowleding should be done when state set to delivered - right now we acknowledge every outgoingDelivery notification
        [self deliveryAcknowledge: myDelivery];

    } else {
        NSLog(@"Signalling deliveryAbort for unknown delivery with messageTag %@ messageId %@ receiver %@", myMessageTag, deliveryDict[@"messageId"], myReceiverId);
        [self deliveryAbort: deliveryDict[@"messageId"] forClient:myReceiverId];
    }
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
        [self validateObject: presence forEntity:@"RPC_TalkPresence_in"];  // TODO: Handle Validation Error
        // NSLog(@"updatePresences presence=%@",presence);
        [self presenceUpdated:presence];
    }
}

- (void) relationshipUpdated: (NSArray*) relationship {
    [self updateRelationship: relationship[0]];
}

- (id) ping {
    return [[NSNull alloc] init];
}

#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@ %d", error, error.code);
    DoneBlock done = ^{
        [self setState: kBackendStopped]; // XXX do we need/want a failed state?
        // [self reconnectWithBackoff];
        [self reconnect];
    };
    if (error.code == 23556) { // constant found in source ... :(
        [self.delegate didFailWithInvalidCertificate: done];
    } else {
        done();
    }
}

- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error {
    NSLog(@"didReceiveInvalidJsonRpcMessage: %@", error);
}

- (void) webSocketDidOpen: (SRWebSocket*) webSocket {
    NSLog(@"webSocketDidOpen performRegistration: %d", _performRegistration);
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
        [self reconnect];
    }
}

- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

#pragma mark - Avatar uploading

- (void) uploadAvatarIfNeeded {
    NSData * myAvatarData = [UserProfile sharedProfile].avatar;
    if (myAvatarData != nil && myAvatarData.length>0) {
        NSString * myCurrentAvatarURL = [UserProfile sharedProfile].avatarURL;
        if (myCurrentAvatarURL == nil || myCurrentAvatarURL.length == 0) {
            [self getAvatarURLWithCompletion:^(NSDictionary *urls) {
                if (urls) {
                    [self uploadAvatarTo:urls[@"uploadUrl"] withDownloadURL:urls[@"downloadUrl"]];
                }
            }];
        }
    }
}

- (void) uploadAvatarTo: (NSString*)toURL withDownloadURL:(NSString*)downloadURL{
    if (self.avatarUploadConnection != nil) {
        NSLog(@"avatar is still being uploaded");
        return;
    }
    NSData * myAvatarData = [UserProfile sharedProfile].avatar;
    // NSLog(@"uploadAvatar starting");
    _avatarBytesTotal = [myAvatarData length];
    _avatarUploadURL = toURL;
    _avatarURL = downloadURL;
    NSURLRequest *myRequest  = [self httpRequest:@"PUT"
                                     absoluteURI:toURL
                                         payloadData:myAvatarData
                                         payloadStream:nil
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

- (void) getAvatarURLWithCompletion:(FileURLRequestHandler)handler {
    NSData * myAvatarImmutableData = [UserProfile sharedProfile].avatar;
    if (myAvatarImmutableData == nil || [myAvatarImmutableData length] == 0) {
        handler(nil);
        return;
    }
    NSMutableData * myAvatarData = [NSMutableData dataWithData:myAvatarImmutableData];
    
    [self createFileForStorageWithSize:@(myAvatarData.length) completionHandler:^(NSDictionary *urls) {
        handler(urls);
    }];
/*
    NSString * myClientID = [UserProfile sharedProfile].clientId;
    [myAvatarData appendData:[myClientID dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSData * myHash = [myAvatarData SHA256Hash];
    NSString * myAvatarFileName = [myHash hexadecimalString];
    NSString * myURL = [[[Environment sharedEnvironment] fileCacheURI] stringByAppendingString:myAvatarFileName];
    return myURL;
 */
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    // NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (connection == _avatarUploadConnection) {
        // NSLog(@"_avatarUploadConnection didReceiveResponse %@, status=%ld, %@", httpResponse, (long)[httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
    } else {
        NSLog(@"ERROR: HXOBackend didReceiveResponse without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == _avatarUploadConnection) {
        /* we do not use this for avatar download, maybe at a later stage */
        NSLog(@"ERROR: HXOBackend didReceiveData - should not be called");
    } else {
        NSLog(@"ERROR: HXOBackend didReceiveData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == _avatarUploadConnection) {
        // NSLog(@"_avatarUploadConnection didSendBodyData %d", bytesWritten);
        _avatarBytesUploaded = totalBytesWritten;
    } else {
        NSLog(@"ERROR: HXOBackend didSendBodyData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == _avatarUploadConnection) {
        NSLog(@"_avatarUploadConnection didFailWithError %@", error);
        _avatarUploadConnection = nil;
    } else {
        NSLog(@"ERROR: HXOBackend didFailWithError without valid connection");
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == _avatarUploadConnection) {
        // NSLog(@"_avatarUploadConnection connectionDidFinishLoading %@", connection);
        _avatarUploadConnection = nil;
        if (_avatarBytesUploaded == _avatarBytesTotal) {
            // set avatar url to new successfully uploaded version
            [UserProfile sharedProfile].avatarURL = _avatarURL;
            [UserProfile sharedProfile].avatarUploadURL = _avatarUploadURL;
            // NSLog(@"_avatarUploadConnection successfully uploaded avatar of size %d", _avatarBytesTotal);
            [self updatePresence];
        } else {
            NSLog(@"ERROR: _avatarUploadConnection only uploaded %d bytes, should be %d",_avatarBytesUploaded, _avatarBytesTotal);
        }
    } else {
        NSLog(@"ERROR: Attachment _avatarUploadConnection connectionDidFinishLoading without valid connection");
    }
}


@end
