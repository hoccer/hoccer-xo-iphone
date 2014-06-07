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
#import "NSString+StringWithData.h"
#import "CCRSA.h"
#import "NSString+URLHelper.h"
#import "NSDictionary+CSURLParams.h"
#import "UserProfile.h"
#import "SoundEffectPlayer.h" // XXX
#import "SocketRocket/SRWebSocket.h"
#import "Group.h"
#import "Crypto.h"
#import "UserProfile.h"
#import "GCHTTPRequestOperation.h"
#import "GCNetworkRequest.h"
#import "UIAlertView+BlockExtensions.h" // XXX
#import "GCNetworkQueue.h"
#import "NSMutableArray+QueueAdditions.h"
#import "HXOEnvironment.h"
#import "HXOUI.h" // XXX
#import "ConversationViewController.h"

#import <sys/utsname.h>

#define DELIVERY_TRACE NO
#define GLITCH_TRACE YES
#define SECTION_TRACE NO
#define CONNECTION_TRACE NO
#define GROUPKEY_DEBUG NO
#define GROUP_DEBUG NO
#define RELATIONSHIP_DEBUG NO
#define TRANSFER_DEBUG NO
#define CHECK_URL_TRACE NO
#define CHECK_CERTS_DEBUG NO
#define DEBUG_DELETION NO
#define LOCKING_TRACE NO


#ifdef DEBUG
#define USE_VALIDATOR YES
#else
#define USE_VALIDATOR NO
#endif

#define FULL_HELLO
#define TRACE_TIME_DIFFERENCE YES

const NSString * const kHXOProtocol = @"com.hoccer.talk.v2";

const int kGroupInvitationAlert = 1;
static const NSUInteger kHXOMaxCertificateVerificationErrors = 3;

static const NSUInteger     kHXOPairingTokenMaxUseCount = 10;
static const NSTimeInterval kHXOPairingTokenValidTime   = 60 * 60 * 24 * 7; // one week

static const int kMaxConcurrentDownloads = 2;
static const int kMaxConcurrentUploads = 2;

const double kHXgetServerTimeInterval = 2 * 60; // get Server Time every n minutes


typedef enum BackendStates {
    kBackendStopped,
    kBackendConnecting,
    kBackendRegistering,
    kBackendAuthenticating,
    kBackendReady,
    kBackendStopping,
    kBackendStateUnknown
} BackendState;

static NSTimer * _stateNotificationDelayTimer;

@interface HXOBackend ()
{
    JsonRpcWebSocket * _serverConnection;
    BackendState       _state;
    double             _backoffTime;
    NSString *         _apnsDeviceToken;
    NSString *         _avatarUploadURL;
    NSString *         _avatarURL;
    BOOL               _performRegistration;
    id                 _internetConnectionObserver;
    NSUInteger         _certificateVerificationErrors;
    NSTimer *          _reconnectTimer;
    NSTimer *          _backgroundDisconnectTimer;
    NSTimer *          _syncTimeTimer;
    GCNetworkQueue *   _avatarDownloadQueue;
    GCNetworkQueue *   _avatarUploadQueue;
    BOOL               _uncleanConnectionShutdown;
    
    NSMutableArray * _attachmentDownloadsWaiting;
    NSMutableArray * _attachmentUploadsWaiting;
    NSMutableArray * _attachmentDownloadsActive;
    NSMutableArray * _attachmentUploadsActive;
    BOOL            _locationUpdatePending;
    unsigned        _loginFailures;
    unsigned        _loginRefusals;
    NSMutableSet * _pendingGroupDeletions;
    NSMutableSet * _idLocks;
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
        _loginFailures = 0;
        _loginRefusals = 0;
        _pendingGroupDeletions = [NSMutableSet new];
        _idLocks = [NSMutableSet new];
        
        _firstConnectionAfterCrashOrUpdate = theAppDelegate.launchedAfterCrash || theAppDelegate.runningNewBuild;
        
        _avatarDownloadQueue = [[GCNetworkQueue alloc] init];
        [_avatarDownloadQueue setMaximumConcurrentOperationsCount:1];
        [_avatarDownloadQueue enableNetworkActivityIndicator:YES];
        
        _avatarUploadQueue = [[GCNetworkQueue alloc] init];
        [_avatarUploadQueue setMaximumConcurrentOperationsCount:1];
        [_avatarUploadQueue enableNetworkActivityIndicator:YES];
        
        [_serverConnection registerIncomingCall: @"incomingDelivery"    withSelector:@selector(incomingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"outgoingDelivery"    withSelector:@selector(outgoingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"pushNotRegistered"   withSelector:@selector(pushNotRegistered:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"presenceUpdated"     withSelector:@selector(presenceUpdatedNotification:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"presenceModified"     withSelector:@selector(presenceModifiedNotification:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"relationshipUpdated" withSelector:@selector(relationshipUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"groupUpdated"        withSelector:@selector(groupUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"groupMemberUpdated"  withSelector:@selector(groupMemberUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"ping"                withSelector:@selector(ping) isNotification: NO];
        [_serverConnection registerIncomingCall: @"getEncryptedGroupKeys" withSelector:@selector(getEncryptedGroupKeys:withResponder:) asyncResult:YES];
        [_serverConnection registerIncomingCall: @"alertUser"           withSelector:@selector(alertUser:) isNotification: YES];
        
        _delegate = theAppDelegate;
        [self cleanupTablesInContext:theAppDelegate.mainObjectContext];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(profileUpdatedByUser:)
                                                     name:@"profileUpdatedByUser"
                                                   object:nil];
        
        void(^reachablityBlock)(NSNotification*) = ^(NSNotification* note) {
            GCNetworkReachabilityStatus status = [[note userInfo][kGCNetworkReachabilityStatusKey] integerValue];
            switch (status) {
                case GCNetworkReachabilityStatusNotReachable:
                    NSLog(@"No connection, checking");
                    [self checkReconnect];
                    break;
                case GCNetworkReachabilityStatusWWAN:
                    NSLog(@"Reachable via WWAN");
                    [self checkReconnect];
                    break;
                case GCNetworkReachabilityStatusWiFi:
                    NSLog(@"Reachable via WiFi");
                    [self checkReconnect];
                    break;
                    
            }
            
        };
        
        _internetConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kGCNetworkReachabilityDidChangeNotification
                                                                                        object:nil
                                                                                         queue:[NSOperationQueue mainQueue]
                                                                                    usingBlock:reachablityBlock];
        
        _attachmentDownloadsWaiting = [[NSMutableArray alloc] init];
        _attachmentUploadsWaiting = [[NSMutableArray alloc] init];
        _attachmentDownloadsActive = [[NSMutableArray alloc] init];
        _attachmentUploadsActive = [[NSMutableArray alloc] init];
        
        _locationUpdatePending = NO;
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    }
    
    return self;
}

-(NSString*)idLock:(NSString*)name {
    @synchronized(_idLocks) {
        id member = [_idLocks member:name];
        if (member != nil) {
            NSLog(@"handing out lock %@",name);
            return member;
        }
        [_idLocks addObject:name];
        NSLog(@"handing out new lock %@",name);
        return [_idLocks member:name];
    }
}

/*
- (void)defaultsChanged:(NSNotification*)aNotification {
    // NSLog(@"defaultsChanged: object %@ info %@", aNotification.object, aNotification.userInfo);
    BOOL updateLocations = [[[HXOUserDefaults standardUserDefaults] valueForKey:@"updateLocations"] boolValue];
    if (updateLocations) {
        [HXOEnvironment.sharedInstance activateLocation];
    } else {
        [HXOEnvironment.sharedInstance deactivateLocation];
        if (_state == kBackendReady && [HXOEnvironment sharedInstance].groupId != nil) {
            [self destroyEnvironmentWithHandler:^(BOOL ok) {
                NSLog(@"Enviroment destroyed = %d",ok);
            }];
        }
    }
}
*/

-(void)sendEnvironmentDestroyWithType:(NSString*)type {
    if (_state == kBackendReady && !_locationUpdatePending) {
        if (_state == kBackendReady) {
            [self destroyEnvironmentType:type withHandler:^(BOOL ok) {
                NSLog(@"Enviroment destroyed = %d",ok);
            }];
        }
    }
}

-(void)sendEnvironmentUpdate {
    if (_state == kBackendReady && !_locationUpdatePending) {
        _locationUpdatePending = YES;
        [self updateEnvironment:[HXOEnvironment sharedInstance] withHandler:^(NSString * groupId) {
            _locationUpdatePending = NO;
        }];
    }
}


-(void) cleanupTablesInContext:(NSManagedObjectContext*)context {
    [self cleanupGroupMembershipTableInContext:context];
    [self cleanupContactTableInContext:context];
}

-(void) cleanupGroupMembershipTableInContext:(NSManagedObjectContext*)context {
    NSEntityDescription *entity = [NSEntityDescription entityForName:[GroupMembership entityName] inManagedObjectContext:context];
    NSFetchRequest *request = [NSFetchRequest new];
    [request setEntity:entity];
    NSError *error;
    NSMutableArray *fetchResults = [[context executeFetchRequest:request error:&error] mutableCopy];
    for (GroupMembership * membership in fetchResults) {
        if (membership.group == nil) {
            NSLog(@"WARNING: cleanupGroupMembershipTable: removing group membership %@ without group",membership.objectID);
            [AppDelegate.instance deleteObject:membership inContext:context];
        }
    }
}

-(void) cleanupContactTableInContext:(NSManagedObjectContext*)context {
    NSEntityDescription *entity = [NSEntityDescription entityForName:[Contact entityName] inManagedObjectContext:context];
    NSFetchRequest *request = [NSFetchRequest new];
    [request setEntity:entity];
    NSError *error;
    NSMutableArray *fetchResults = [[context executeFetchRequest:request error:&error] mutableCopy];
    for (Contact * contact in fetchResults) {
        [self checkRelationsipStateForGroupMembershipOfContact:contact];
    }
}

-(void) checkRelationsipStateForGroupMembershipOfContact:(Contact*) contact {
    if (contact.groupMemberships.count > 0) {
        if (contact.isNotRelated || contact.isKept) {
            contact.relationshipState = kRelationStateGroupFriend;
        }
    } else {
        if (contact.isGroupFriend) {
            contact.relationshipState = kRelationStateNone;
        }
    }
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
    [[HXOBackend instance] updateConnectionStatusInfoFromState:kBackendStateUnknown];
}

+ (HXOBackend*)instance {
    return ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
}

- (NSString*) stateString: (BackendState) state {
    switch (state) {
        case kBackendStopped:
            return @"backend_stopped";
            break;
        case kBackendConnecting:
            return @"backend_connecting";
            break;
        case kBackendRegistering:
            return @"backend_registering";
            break;
        case kBackendAuthenticating:
            return @"backend_authenticating";
            break;
        case kBackendReady:
            return @"backend_ready";
            break;
        case kBackendStopping:
            return @"backend_stopping";
            break;
        case kBackendStateUnknown:
            return @"unknown";
            break;
    }
}

- (void) setState: (BackendState) state {
    if (CONNECTION_TRACE) NSLog(@"backend state %@ -> %@", [self stateString: _state], [self stateString: state]);
    BackendState oldState= _state;
    _state = state;
    if (_state == kBackendReady) {
        _backoffTime = 0.0;
        if (!_syncTimeTimer.isValid) {
            _syncTimeTimer = [NSTimer scheduledTimerWithTimeInterval:kHXgetServerTimeInterval target:self selector:@selector(syncTime) userInfo:nil repeats:YES];
        }
    } else {
        if (_syncTimeTimer.isValid) {
            [_syncTimeTimer invalidate];
            _syncTimeTimer = nil;
        }
    }
    [self updateConnectionStatusInfoFromState:oldState];
    if (state == kBackendReady) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"loginSucceeded"
                                                            object:self
                                                          userInfo:nil];
        
    }
}

// notify everyone who is interested in displaying the status
- (void) updateConnectionStatusInfoFromState:(BackendState)oldState {
    NSString * newInfo;
    BOOL normal = NO;
    BOOL progress = NO;
    BOOL reachable = [self.delegate.internetReachabilty isReachable];
    if (reachable) {
        newInfo = [self stateString: _state];
        normal = (_state == kBackendReady) ;
        progress = _state > oldState &&
            _state > kBackendConnecting &&
            _state < kBackendStopping &&
            oldState != kBackendStateUnknown &&
            !_stateNotificationDelayTimer.isValid;
    } else {
        newInfo = @"backend_no_internet";
    }
    [self cancelStateNotificationDelayTimer];
    id userInfo = @{ @"statusinfo":NSLocalizedString(newInfo, @"connection states"),
                     @"normal":@(normal) };
    if (normal || progress || !reachable) {
        if (CONNECTION_TRACE) NSLog(@"immediate notification for %@",userInfo);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"connectionInfoChanged"
                                                            object:self
                                                          userInfo:userInfo
         ];
    } else {
        if (CONNECTION_TRACE) NSLog(@"launched Timer for %@",userInfo);
        _stateNotificationDelayTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(updateConnectionStatusInfoNow:) userInfo:userInfo repeats:NO];
    }
}

- (void)cancelStateNotificationDelayTimer {
    if (_stateNotificationDelayTimer.isValid) {
        [_stateNotificationDelayTimer invalidate];
        _stateNotificationDelayTimer = nil;
    }    
}

- (void) updateConnectionStatusInfoNow:(NSTimer *)theTimer {
    if (CONNECTION_TRACE) NSLog(@"fired %@",theTimer.userInfo);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"connectionInfoChanged"
                                                        object:self
                                                      userInfo:theTimer.userInfo];
    _stateNotificationDelayTimer = nil;
}


- (void) saveServerTime:(NSDate *) theTime {
    self.latestKnownServerTime = theTime;
    self.latestKnownServerTimeAtClientTime = [NSDate date];
    self.latestKnownServerTimeOffset = [self.latestKnownServerTime timeIntervalSinceDate:self.latestKnownServerTimeAtClientTime];
    // offest is positive if server time is ahead of client time
    if (TRACE_TIME_DIFFERENCE) NSLog(@"Server time differs by %f secs. from our time, estimated server time = %@", self.latestKnownServerTimeOffset, [self estimatedServerTime]);
}

#define DEBUG_TIME_DAY (86400 * 1000)
#define DEBUG_TIME_OFFSET (0 * DEBUG_TIME_DAY)

- (NSDate*) estimatedServerTime {
    return [NSDate dateWithTimeIntervalSinceNow:self.latestKnownServerTimeOffset];
}

- (Attachment*) cloneAttachment:(const Attachment*) attachment whenReady:(AttachmentCompletionBlock)attachmentCompleted {
    Attachment * newAttachment = nil;
    if (attachment) {
        newAttachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: self.delegate.currentObjectContext];
        
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
        } else if ([newAttachment.mediaType isEqualToString:@"data"]) {
            [newAttachment makeDataAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        }
    }
    return newAttachment;
}


// calls sendmessage after cloning the attachment
- (void) forwardMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment {
    
    Attachment * newAttachment = nil;
    
    AttachmentCompletionBlock completion  = ^(Attachment * myAttachment, NSError *myerror) {
        if (myerror == nil) {
            [self sendMessage:text toContactOrGroup:contact toGroupMemberOnly:privateGroupMessageContact withAttachment:myAttachment];
        }
    };
    
    newAttachment = [self cloneAttachment:attachment whenReady:completion];
    if (newAttachment == nil) {
        // send message without attachment right now, we will not get a completion call here
        [self sendMessage: text toContactOrGroup:contact toGroupMemberOnly:privateGroupMessageContact withAttachment:nil];
    }
}

- (void) finishSendMessage:(HXOMessage*)message toContact:(Contact*)contact withDelivery:(Delivery*)delivery withAttachment:(Attachment*)attachment {
    if (CONNECTION_TRACE) {NSLog(@"finishSendMessage: %@ toContact: %@ withDelivery: %@ withAttachment: %@", message, contact, delivery, attachment);}

    message.sourceMAC = [message computeHMAC];
    message.messageTag = [message sourceMACString];
    
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOSignMessages]) {
        [message sign];
        if ([message verifySignatureWithPublicKey:[[CCRSA sharedInstance] getPublicKeyRef]]) {
            NSLog(@"Outgoing signature verified");
        } else {
            NSLog(@"Outgoing signature verification failed");
        }
    }
    
    [self.delegate.mainObjectContext refreshObject: contact mergeChanges: YES];

    // Delivery may already be in state failed, e.g. if the public key is missing.
    BOOL deliveryFailed = [delivery.state isEqualToString: kDeliveryStateFailed];
    if (_state == kBackendReady && ! deliveryFailed) {
        [self deliveryRequest: message withDeliveries: @[delivery]];
    }
    
    if (attachment != nil && attachment.state == kAttachmentWantsTransfer && ! deliveryFailed) {
        [self enqueueUploadOfAttachment:attachment];
    }
    
    [self.delegate saveDatabase];
    if ( ! deliveryFailed) {
        [SoundEffectPlayer messageSent];
    }
    [self checkTransferQueues]; // this can go when we are sure transferqueues are bugfree
    
}

// TODO: contact should be an array of contacts
- (void) sendMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment {
    
    HXOMessage * message =  (HXOMessage*)[NSEntityDescription insertNewObjectForEntityForName: [HXOMessage entityName] inManagedObjectContext: self.delegate.mainObjectContext];
    message.body = text;
    message.timeSent = [self estimatedServerTime]; // [NSDate date];
    message.contact = contact;
    message.timeAccepted = [self estimatedServerTime];
    message.isOutgoing = @YES;
    // message.timeSection = [contact sectionTimeForMessageTime: message.timeSent];
    message.messageId = @"";
    //message.messageTag = [NSString stringWithUUID];
    message.senderId = [UserProfile sharedProfile].clientId;

    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.mainObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    
    if ([contact.type isEqualToString:@"Group"]) {
        delivery.group = (Group*)contact;
        delivery.receiver = privateGroupMessageContact;
        message.sharedKeyIdSalt = delivery.group.sharedKeyIdSalt;
        message.sharedKeyId = delivery.group.sharedKeyId;
    } else {
        delivery.receiver = contact;
        delivery.group = nil;
    }
    
    [message setupOutgoingEncryption];
    
    if (attachment != nil) {
        message.attachment = attachment;
        attachment.cipheredSize = [attachment calcCipheredSize];
        [self createUrlsForTransferOfAttachmentOfMessage:message];
        return;
    }
    [self finishSendMessage:message toContact:contact withDelivery:delivery withAttachment:attachment];
}

- (void) createUrlsForTransferOfAttachmentOfMessage:(HXOMessage*)message {
    if (CONNECTION_TRACE) {NSLog(@"createUrlsForTransferOfAttachmentOfMessage: %@", message);}
    Attachment * attachment = message.attachment;
    [self createFileForTransferWithSize:attachment.cipheredSize completionHandler:^(NSDictionary *urls) {
        if (urls && [urls[@"uploadUrl"] length]>0 && [urls[@"downloadUrl"] length]>0 && [urls[@"fileId"] length]>0) {
            if (CONNECTION_TRACE) NSLog(@"createUrlsForTransferOfAttachmentOfMessage: got attachment urls=%@", urls);
            attachment.uploadURL = urls[@"uploadUrl"];
            attachment.remoteURL = urls[@"downloadUrl"];
            message.attachmentFileId = urls[@"fileId"];
            attachment.transferSize = @(0);
            attachment.cipherTransferSize = @(0);
            // NSLog(@"sendMessage: message.attachment = %@", message.attachment);
            [self finishSendMessage:message toContact:message.contact withDelivery:message.deliveries.anyObject withAttachment:attachment];
        } else {
            NSLog(@"ERROR: Could not get attachment urls, retrying");
            [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(retryCreateUrlsForTransferOfAttachment:) userInfo:message repeats:NO];
        }
    }];
}

- (void) retryCreateUrlsForTransferOfAttachment:(NSTimer*)theTimer {
    HXOMessage * message = [theTimer userInfo];
    [self createUrlsForTransferOfAttachmentOfMessage:message];
}

-(HXOMessage*) getMessageById:(NSString*)messageId inContext:(NSManagedObjectContext*) context {
    NSError *error;
    NSDictionary * vars = @{ @"messageId" : messageId};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"MessageByMessageId" substitutionVariables: vars];
    NSArray *messages = [context executeFetchRequest:fetchRequest error:&error];
    if (messages == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    if (messages.count > 0) {
        if (messages.count != 1) {
            NSLog(@"ERROR: Database corrupted, duplicate messages with id %@ in database", messageId);
            return nil;
        }
        HXOMessage * message = messages[0];
        return message;
    }
    return nil;
}

- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary inContext:(NSManagedObjectContext *)context {
    // Ignore duplicate messages. This happens if a message is offered to us by the server multiple times
    // while we are in the background. These messages end up in the input buffer of the socket and are delivered
    // when we enter foreground before the connection times out. Another solution would be to disconnect while
    // we are in background but currently I prefer it this way.
    NSLog(@"receiveMessage");
    NSError *error;
    @synchronized([self idLock:messageDictionary[@"messageId"]]) {
        NSDictionary * vars = @{ @"messageId" : messageDictionary[@"messageId"]};
        NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"MessageByMessageId" substitutionVariables: vars];
        NSArray *messages = [context executeFetchRequest:fetchRequest error:&error];
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
            
            [self.delegate saveContext:context];
            NSManagedObjectID * deliverObjId = oldDelivery.objectID;
            NSString * oldMessageId = oldMessage.messageId;
            NSLog(@"receiveMessage: scheduling deliveryConfirm");
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                NSLog(@"receiveMessage: starting deliveryConfirm on old");
                Delivery * oldDelivery = (Delivery *)[context objectWithID:deliverObjId];
                [self deliveryConfirm: oldMessageId withDelivery: oldDelivery];
                NSLog(@"receiveMessage: done deliveryConfirm on old");
            }];
            return;
        }
        
        if (![deliveryDictionary[@"keyCiphertext"] isKindOfClass:[NSString class]]) {
            NSLog(@"ERROR: receiveMessage: aborting received message without keyCiphertext, id= %@", vars[@"messageId"]);
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                [self deliveryAbort:messageDictionary[@"messageId"] forClient:deliveryDictionary[@"receiverId"]];
            }];
            return;
        }
        
        SecKeyRef myPrivateKeyRef = [[CCRSA sharedInstance] getPrivateKeyRefForPublicKeyIdString:deliveryDictionary[@"keyId"]];
        if (myPrivateKeyRef == NULL) {
            NSLog(@"ERROR: receiveMessage: aborting received message with bad keyId (I have no matching private key) = %@, my keyId = %@", deliveryDictionary[@"keyId"],[[UserProfile sharedProfile] publicKeyId]);
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                [self deliveryAbort:messageDictionary[@"messageId"] forClient:deliveryDictionary[@"receiverId"]];
            }];
            return;
        }
        
        NSLog(@"receiveMessage: inserting new message and delivery");
        HXOMessage * message = [NSEntityDescription insertNewObjectForEntityForName: [HXOMessage entityName] inManagedObjectContext: context];
        Delivery * delivery = [NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: context];
        //AUTOREL [message.deliveries addObject: delivery];
        delivery.message = message;
        
        Attachment * attachment = nil;
        if (messageDictionary[@"attachment"] != nil) {
            attachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: context];
            message.attachment = attachment;
        }
        
        NSString * groupId = deliveryDictionary[@"groupId"];
        NSString * senderId = deliveryDictionary[@"senderId"];
        NSString * receiverId = deliveryDictionary[@"receiverId"];
        
        Contact * sender = [self getContactByClientId:senderId inContext:context];
        Contact * receiver = [self getContactByClientId:receiverId inContext:context];
        Group * group = nil;
        if (groupId != nil) {
            group = [self getGroupById:groupId inContext:context];
        }
        
        // Abort messages from unknown sender. This happens if someone becomes a member of a group,
        // sends some messages and leaves the group again while this client is offline.
        // There is a small possibilty of message loss, though. It happens if a message by some client
        // to a group arrives before the membership is known to this client.
        if (sender == nil || (groupId != nil && group == nil)) {
            NSLog(@"Strange message:");
            if (sender == nil) {
                NSLog(@"from unknown sender with id %@", senderId);
            } else {
                NSLog(@"from known sender with name %@ relation %@", sender.nickName, sender.relationshipState);
            }
            
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                [self deliveryAbort:messageDictionary[@"messageId"] forClient:deliveryDictionary[@"receiverId"]];
            }];
            [AppDelegate.instance deleteObject:message inContext:context];
            [AppDelegate.instance deleteObject:delivery inContext:context];
            return;
        }
        NSLog(@"receiveMessage: bulding stuff started");
        Contact * contact = nil;
        if (group != nil) {
            contact = group;
        } else {
            contact = sender;
        }
        
        message.isOutgoing = @NO;
        message.isRead = @NO;
        message.timeReceived = [self estimatedServerTime];
        // message.timeSection = [contact sectionTimeForMessageTime: message.timeAccepted];
        message.timeSection = message.timeAccepted;
        message.contact = contact;
        contact.rememberedLastVisibleChatCell = nil; // make view to scroll to end when user enters chat
        [contact.messages addObject: message];
        
        delivery.receiver = receiver;
        delivery.sender = sender;
        delivery.group = group;
        [delivery updateWithDictionary: deliveryDictionary];
        
        message.saltString = messageDictionary[@"salt"]; // set up before decryption
        [message updateWithDictionary: messageDictionary];
        
        if (message.sharedKeyId != nil) {
            NSData * computedId = [Crypto calcSymmetricKeyId:delivery.keyCleartext withSalt:message.sharedKeyIdSalt];
            if (![message.sharedKeyId isEqualToData:computedId]) {
                NSLog(@"ERROR: Message sharedKeyId is %@, should be %@",[computedId asBase64EncodedString], message.sharedKeyIdString);
            } else {
                NSLog(@"INFO: Message sharedKeyId is ok");
            }
        }
        
        BOOL tagIsUUID = [AppDelegate validateString:message.messageTag withPattern:@"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"];
        
        if (!tagIsUUID || message.sourceMAC != nil) {
            if (message.attachment != nil) {
                message.attachment.origCryptedJsonString = messageDictionary[@"attachment"];
            }
            message.destinationMAC = [message computeHMAC];
            if (message.sourceMAC == nil) {
                message.sourceMACString = message.messageTag; // TODO: remove when everyone is using the hmac field
            }
            if (message.sourceMAC != nil) {
                if (![message.sourceMAC isEqualToData:message.destinationMAC]) {
                    NSLog(@"ERROR: Message hmac is %@, should be %@",[message.destinationMAC asBase64EncodedString], message.sourceMACString);
                    // TODO: throw away message or mark as bad
                } else {
                    NSLog(@"INFO: Message hmac is ok");
                }
            }
            if (message.signature != nil && message.signature.length > 0) {
                SecKeyRef peerKey = [[CCRSA sharedInstance] getPeerKeyRef:message.senderId];
                if (peerKey != NULL) {
                    if ([message verifySignatureWithPublicKey:peerKey]) {
                        NSLog(@"INFO: incoming signature ok for message %@ from client %@", message.messageId, message.senderId);
                    } else {
                        NSLog(@"ERROR: bad incoming signature for message %@ from client %@", message.messageId, message.senderId);
                    }
                } else {
                    NSLog(@"ERROR:no public key for signature verification of message %@ from client %@", message.messageId, message.senderId);
                }
            }
        }
        
        contact.latestMessageTime = message.timeAccepted;
        
        [context performBlock:^{
            NSManagedObjectID * contactId = contact.objectID;
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                NSLog(@"receiveMessage:refreshObject");
                [context refreshObject: [context objectWithID:contactId] mergeChanges: YES];
                NSLog(@"receiveMessage:refreshObject done");
            }];
        }];
        
        [self.delegate saveContext:context];
        NSManagedObjectID * messageObjId = message.objectID;
        NSManagedObjectID * deliveryObjId = delivery.objectID;
        
        NSLog(@"receiveMessage: scheduling new deliveryConfirm");
        [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
            NSLog(@"receiveMessage: starting new deliveryConfirm");
            Delivery * delivery = (Delivery *)[context objectWithID:deliveryObjId];
            HXOMessage * message = (HXOMessage *)[context objectWithID:messageObjId];
            Attachment * attachment = message.attachment;
            if (attachment.state == kAttachmentWantsTransfer) {
                [self enqueueDownloadOfAttachment:attachment];
            }
            if (DELIVERY_TRACE,YES) {NSLog(@"receiveMessage: confirming new message & delivery with state '%@' for tag %@ id %@",delivery.state, delivery.message.messageTag, message.messageId);}
            [self deliveryConfirm: message.messageId withDelivery: delivery];
            if (message.attachment == nil) {
                [SoundEffectPlayer messageArrived];
            }
            [self checkTransferQueues];
            
            id userInfo = @{ @"message":message };
            [[NSNotificationCenter defaultCenter] postNotificationName:@"receivedNewHXOMessage"
                                                                object:self
                                                              userInfo:userInfo
             ];
        }];
    }
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
    [self srpPhase1WithClientId: [UserProfile sharedProfile].clientId A: A andHandler:^(NSString * challenge, NSDictionary * errorReturned) {
        if (challenge == nil) {
            NSLog(@"SRP phase 1 failed");
            // can happen if the client thinks the connection was closed, but the server still considers it as open
            // so let us also close and try again
            
            NSString * errorMessage;
            if (errorReturned == nil) {
                errorMessage = @"unknown error";
            } else if ([errorReturned isKindOfClass:[NSDictionary class]]) {
                errorMessage = errorReturned[@"message"];
            } else {
                errorMessage = [errorReturned description];
            }
            
            if (errorReturned != nil &&
                ([errorMessage isEqualToString:@"No such client"] ||
                 [errorMessage isEqualToString:@"Authentication failed"] ||
                 [errorMessage isEqualToString:@"Bad salt"] ||
                 [errorMessage isEqualToString:@"Not registered"] ))
            {
                // check if our credentials were refused
                NSLog(@"Login credentials refused in SRP phase1 with ‘%@', loginRefusals=%d", errorMessage, _loginRefusals);
                _loginRefusals++;
                if (_loginRefusals >= 3) {
                    [AppDelegate.instance showInvalidCredentialsWithInfo:errorMessage withContinueHandler:^{
                    }];
                } else {
                    [self stopAndRetry];
                }
            } else {
                _loginFailures++;
                if (_loginFailures >= 3) {
                    NSLog(@"Login SRP phase 1 failed %d times", _loginFailures);
                    [AppDelegate.instance showLoginFailedWithInfo:errorMessage withContinueHandler:^{
                        _loginFailures = 0;
                        [self stopAndRetry];
                    }];
                } else {
                    [self stopAndRetry];
                }
            }
            
        } else {
            NSError * error;
            NSString * M = [[UserProfile sharedProfile] processSrpChallenge: challenge error: &error];
            if (M == nil) {
                NSLog(@"%@", error);
                // possible tampering ... trigger reconnect by closing the socket
                [self stopAndRetry];
            } else {
                [self srpPhase2: M handler:^(NSString * HAMK, NSDictionary * errorReturned) {
                    if (HAMK != nil) {
                        NSError * error;
                        BOOL success = [[UserProfile sharedProfile] verifySrpSession: HAMK error: &error];
                        if (! success) {
                            NSLog(@"%@", error);
                        }
                        [self didFinishLogin: success];
                        _loginFailures = 0;
                        _loginRefusals = 0;
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
        if ([self quickStart]) {
            [self performParallelSync];
        } else {
            [self postLoginSynchronize];
        }
    } else {
        [self stopAndRetry];
    }
}

-(void)syncFailed {
    [self stopAndRetry];
}

- (void)performParallelSync {
    BOOL forced = self.firstConnectionAfterCrashOrUpdate||[self fullSync];
    if (forced) {
        NSLog(@"Running forced full sync");
    }
    [self hello];
    [self syncPresencesWithForce:forced withCompletion:^(BOOL ok) {
        if (!ok) [self syncFailed];
    }];
    [self syncRelationshipsWithForce:forced withCompletion:^(BOOL ok) {
        if (!ok) [self syncFailed];
    }];
    [self flushPendingInvites];
    [self verifyKeyWithHandler:^(BOOL keyOk, BOOL ok) {
        if (ok) {
            if (!keyOk) {
                [self updateKeyWithHandler:^(BOOL ok) {
                    if (!ok) [self syncFailed];
                }];
            }
        } else {
            [self syncFailed];
        }
    }];
    [self updatePresenceWithHandler:^(BOOL ok) {
        if (!ok) [self syncFailed];
    }];
    
    [self syncGroupsWithForce:forced withCompletionContext:self.delegate.mainObjectContext withCompletion:^(BOOL ok) {
        if (!ok) [self syncFailed];
        else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"postLoginSyncCompleted"
                                                                object:self
                                                              userInfo:nil
             ];
            if (AppDelegate.instance.conversationViewController !=nil && AppDelegate.instance.conversationViewController.inNearbyMode) {
                [HXOEnvironment.sharedInstance setActivation:YES];
            }
        }
    }];
    [self ready:^(BOOL ok)   {
        if (!ok) [self syncFailed];
    }];
    
    [self finishFirstConnectionAfterCrashOrUpdate];
    [self flushPendingMessages];
    [self flushPendingFiletransfers];

    
}

- (void)postLoginSynchronize {
    BOOL forced = self.firstConnectionAfterCrashOrUpdate||[self fullSync];
    if (forced) {
        NSLog(@"Running forced full sync");
    }
    [self hello];
    [self syncPresencesWithForce:forced withCompletion:^(BOOL ok1) {
        if (ok1) {
            [self syncRelationshipsWithForce:forced withCompletion:^(BOOL ok2) {
                if (ok2) {
                    [self flushPendingInvites];
                    [self verifyKeyWithHandler:^(BOOL keyOk, BOOL ok3) {
                        if (ok3) {
                            if (!keyOk) {
                                [self updateKeyWithHandler:^(BOOL ok4) {
                                    if (ok4) {
                                        [self postKeySynchronize];
                                    } else {
                                        [self syncFailed];
                                    }
                                }];
                            } else {
                                [self postKeySynchronize];
                            }
                        } else {
                            [self syncFailed];
                        }
                    }];
                } else {
                    [self syncFailed];
                }
            }];
        } else {
            [self syncFailed];
        }
    }];
}

- (void)postKeySynchronize {
    BOOL forced = self.firstConnectionAfterCrashOrUpdate||[self fullSync];
    [self updatePresenceWithHandler:^(BOOL ok1) {
        if (ok1) {
            [self syncGroupsWithForce:forced withCompletionContext:self.delegate.mainObjectContext withCompletion:^(BOOL ok2) {
                if (ok2) {
                    [self ready:^(BOOL ok3) {
                        if (ok3) {
                            [self finishFirstConnectionAfterCrashOrUpdate];
                            [self flushPendingMessages];
                            [self flushPendingFiletransfers];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"postLoginSyncCompleted"
                                                                                object:self
                                                                              userInfo:nil
                             ];
                            if (AppDelegate.instance.conversationViewController !=nil && AppDelegate.instance.conversationViewController.inNearbyMode) {
                                [HXOEnvironment.sharedInstance setActivation:YES];
                            }
                        } else {
                            [self syncFailed];
                        }
                    }];
                } else {
                    [self syncFailed];
                }
            }];
        } else {
            [self syncFailed];
        }
    }];
}

- (void) finishFirstConnectionAfterCrashOrUpdate {
    _uncleanConnectionShutdown = NO;
    if (self.firstConnectionAfterCrashOrUpdate) {
        self.firstConnectionAfterCrashOrUpdate = NO;
        [self makeSureAvatarUploaded];
    }
}

- (void) generatePairingTokenWithHandler: (InviteTokenHanlder) handler {
    [self generatePairingToken: kHXOPairingTokenMaxUseCount validFor: kHXOPairingTokenValidTime tokenHandler: handler];
}

-(Contact *) getContactByClientId:(NSString *) theClientId inContext:(NSManagedObjectContext *)context{
    NSDictionary * vars = @{ @"clientId" : theClientId};    
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"ContactByClientId" substitutionVariables: vars];
    NSError *error;
    NSArray *contacts = [context executeFetchRequest:fetchRequest error:&error];
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

-(Group *) getGroupById:(NSString *) theGroupId inContext:(NSManagedObjectContext *)context{
    NSDictionary * vars = @{ @"clientId" : theGroupId};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"GroupByClientId" substitutionVariables: vars];
    NSError *error;
    NSArray *groups = [context executeFetchRequest:fetchRequest error:&error];
    if (groups == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Group * group = nil;
    if (groups.count == 1) {
        group = groups[0];
    } else {
        if (groups.count > 1) {
            NSLog(@"### ERROR: more than 1 group with id %@ in database", theGroupId);
            abort();
        }
        if (GROUP_DEBUG) NSLog(@"Group ClientId %@ not in contacts:", theGroupId);
    }
    return group;
}

-(Group *) getGroupById:(NSString *)theGroupId orByTag:(NSString *)theGroupTag inContext:(NSManagedObjectContext *)context {
    Group * group = [self getGroupById: theGroupId inContext:context];
    if (group == nil) {
        group = [self getGroupByTag:theGroupTag inContext:context];
        if (group == nil) {
            if (GROUP_DEBUG) NSLog(@"INFO: getGroupById:orByTag: unknown group with id=%@ or tag %@",theGroupId,theGroupTag);
        }
    }
    return group;
}


-(Group *) getGroupByTag:(NSString *) theGroupTag inContext:(NSManagedObjectContext *)context {
    NSDictionary * vars = @{ @"groupTag" : theGroupTag};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"GroupByTag" substitutionVariables: vars];
    NSError *error;
    NSArray *groups = [context executeFetchRequest:fetchRequest error:&error];
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
            Invite * invite =  (Invite*)[NSEntityDescription insertNewObjectForEntityForName: [Invite entityName] inManagedObjectContext: self.delegate.mainObjectContext];
            invite.token = token;
        }
    }
}

- (BOOL) isInviteTokenInDatabase: (NSString *) token {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * inviteEntity = [NSEntityDescription entityForName: [Invite entityName] inManagedObjectContext: self.delegate.currentObjectContext];
    [fetchRequest setEntity: inviteEntity];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.token == %@", token];
    [fetchRequest setPredicate: predicate];
    NSError *error;
    NSArray *invites = [self.delegate.currentObjectContext executeFetchRequest:fetchRequest error:&error];
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
    if (_state != kBackendStopped) {
        // TODO: this is a quick fix to handle the case when the app is left and immediately entered again
        // We should handle this case more gracefully
        [_serverConnection close];
    }
    _performRegistration = performRegistration;
    [self setState: kBackendConnecting];
    [_serverConnection openWithURLRequest: [self urlRequest] protocols: @[kHXOProtocol] allowUntrustedConnections:[HXOBackend allowUntrustedServerCertificate]];
}

- (void) stop {
    [self setState: kBackendStopping];
    [_serverConnection close];
    [self clearWaitingAttachmentTransfers];
}

- (void) stopAndRetry {
    [self setState: kBackendStopped];
    [_serverConnection close];
}

// called by internetReachabilty Observer when internet connection is lost or gained
- (void) disconnect {
    if (_reconnectTimer != nil) {
        [_reconnectTimer invalidate];
        _reconnectTimer = nil;
    }
    if (_state != kBackendStopped && _state != kBackendStopping) {
        [self stop];
    }
}

-(BackendState)getBackendState {
    return _state;
}


// called by internetReachabilty Observer when internet connection seems to be lost
-(void) checkReconnect {
    if (_state == kBackendStopped) {
        NSLog(@"checkReconnect: backend stopped, try reconnecting");
        [self reconnect];
        return;
    }
    if (_state == kBackendReady) {
        // check if we might be still connected
        NSLog(@"checkReconnect: backend still in ready state, try bing");
        [self bing:^(BOOL ok) {
            // we still believe to be connected, but bing failed
            if (!ok && [self getBackendState] == kBackendReady) {
                NSLog(@"checkReconnect: bing failed, disconnect and start over");
                [self disconnect];
                [self reconnect];
            }
            if (_state == kBackendStopped) {
                NSLog(@"checkReconnect: backend now stopped, try reconnecting");
                [self reconnect];
            }
        }];
    } else {
        NSLog(@"checkReconnect: backend in state %@, doing nothing", [self stateString: _state]);
    }
}

- (void) reconnect {
    if (_reconnectTimer != nil) {
        [_reconnectTimer invalidate];
        _reconnectTimer = nil;
    }
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground || state == UIApplicationStateInactive)
    {
        // do not reconnect when in background
        return;
    }
    if ([self.delegate.internetReachabilty isReachable]) {
        [self start: _performRegistration];
    }
}

- (void) reconnectWithBackoff {
    if (_backoffTime == 0) {
        _backoffTime = 0.5 + ((double)rand() / RAND_MAX);
    } else {
        _backoffTime = MIN(2 * _backoffTime, 10);
    }
    NSLog(@"reconnecting in %f seconds", _backoffTime);
    _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval: _backoffTime target: self selector: @selector(reconnect) userInfo: nil repeats: NO];
}


- (NSURLRequest*) urlRequest {
    NSURL * url = [NSURL URLWithString: [[Environment sharedEnvironment] talkServer]];
#ifdef DEBUG
    NSString * debugServerURL = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXODebugServerURL];
    if (debugServerURL && ! [debugServerURL isEqualToString: @""]) {
        url = [NSURL URLWithString: debugServerURL];
    }
#endif
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
            if (CHECK_CERTS_DEBUG) NSLog(@"certificate: path: %@ cert: %@", path, certificate);
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
    NSArray *deliveries = [self.delegate.mainObjectContext executeFetchRequest:fetchRequest error:&error];
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
    // for each message collect those deliveries that have state 'new' and send them out
    for (HXOMessage * message in pendingMessages) {
        if (message.attachment != nil && (message.attachment.uploadURL == nil || message.attachment.uploadURL.length == 0)) {
            // get attachment transfer url in case there are none yet
            [self createUrlsForTransferOfAttachmentOfMessage:message];
        } else {
            [self finishSendMessage:message toContact:message.contact withDelivery:message.deliveries.anyObject withAttachment:message.attachment];
        }
        
    }
}

- (void) flushPendingInvites {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * inviteEntity = [NSEntityDescription entityForName: [Invite entityName] inManagedObjectContext: self.delegate.mainObjectContext];
    [fetchRequest setEntity: inviteEntity];
    NSError *error;
    NSArray *invites = [self.delegate.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (invites == nil) {
        NSLog(@"ERROR: flushPendingInvites: failed to execute fetch request: %@", error);
        abort();
    }
    for (Invite * invite in invites) {
        [self pairByToken: invite.token];
        [AppDelegate.instance deleteObject:invite];
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
    NSEntityDescription *entity = [NSEntityDescription entityForName: entityName inManagedObjectContext: self.delegate.currentObjectContext];
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
    NSArray *fetchResults = [self.delegate.currentObjectContext
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

- (void) syncRelationshipsWithForce:(BOOL)forceAll withCompletion:(GenericResultHandler)completion {
    NSDate * latestChange;
    if (forceAll) {
        latestChange = [NSDate dateWithTimeIntervalSince1970:0]; 
    } else {
        latestChange = [self getLatestChangeDateForContactRelationships];
    }
    // NSLog(@"latest date %@", latestChange);
    [self getRelationships: latestChange relationshipHandler:^(NSArray * changedRelationships) {
        if (changedRelationships != nil) {
            for (NSDictionary * relationshipDict in changedRelationships) {
                [self updateRelationship: relationshipDict];
            }
            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
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
    NSArray *messages = [myDelegate.currentObjectContext executeFetchRequest:fetchRequest error:&myError];

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
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        if (USE_VALIDATOR) [self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
        
        NSString * clientId = relationshipDict[@"otherClientId"];
        if ([clientId isEqualToString: [UserProfile sharedProfile].clientId]) {
            return;
        }
        @synchronized([self idLock:clientId]) {
            if (LOCKING_TRACE) NSLog(@"Entering synchronized updateRelationship %@",clientId);
            Contact * contact = [self getContactByClientId: clientId inContext:context];
            // XXX The server sends relationship updates with state 'none' even after depairing.
            if ([relationshipDict[@"state"] isEqualToString: @"none"]) {
                [self checkRelationsipStateForGroupMembershipOfContact:contact];
                if (contact != nil && !contact.isNotRelated && !contact.isKept && !contact.isGroupFriend) {
                    contact.relationshipState = kRelationStateNone;
                    //[self handleDeletionOfContact:contact withForce:NO];
                    [self handleDeletionOfContact:contact withForce:NO inContext:context];
                }
                if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r1) %@",clientId);
                return;
            }
            if (contact == nil) {
                contact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:context];
                contact.type = [Contact entityName];
                contact.clientId = clientId;
            }
            if (contact.nickName.length > 0 && !contact.isFriend && [relationshipDict[@"state"] isEqualToString: kRelationStateFriend]) {
                [self newFriendAlertForContact:contact];
            } else if (!contact.isBlocked && [relationshipDict[@"state"] isEqualToString: kRelationStateBlocked]) {
                [self blockedAlertForContact:contact];
            }
            // NSLog(@"relationship Dict: %@", relationshipDict);
            [contact updateWithDictionary: relationshipDict];
            [self checkRelationsipStateForGroupMembershipOfContact:contact];
            [self.delegate saveContext:context];
            if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere %@",clientId);
        }
    }];
}

- (void) newFriendAlertForContact:(Contact*)contact {
    if (contact.friendMessageShown) {
        return;
    }
    contact.friendMessageShown = YES;
    NSString * contactName = contact.nickName;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_new_friend_message",nil), contactName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_new_friend_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

- (void) blockedAlertForContact:(Contact*)contact {
    NSString * contactName = contact.nickName;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_blocked_message",nil), contactName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_blocked_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

- (void) removedAlertForContact:(Contact*)contact {
    NSString * contactName = contact.nickName;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_relationship_removed_message",nil), contactName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_relationship_removed_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

- (NSString*) groupMembershipListofContact:(Contact*)contact {
    NSMutableArray * groups = [[NSMutableArray alloc] init];

    [contact.groupMemberships enumerateObjectsUsingBlock:^(GroupMembership* member, BOOL *stop) {
        if (![member.contact isEqual: member.group]) {
            if (member.group.nickName != nil) {
                [groups addObject: member.group.nickName];
            } else {
                [groups addObject: @"?"];
            }
        }
    }];
    if (groups.count == 0) {
        return @"-";
    }
    return [groups componentsJoinedByString:@", "];
}


- (void) removedButKeptInGroupAlertForContact:(Contact*)contact {
    
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_kept_and_relationship_removed_message",nil), contact.nickName, [self groupMembershipListofContact:contact]];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_relationship_removed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

- (void) askForDeletionOfContact:(Contact*)contact {
    [self.delegate saveContext:self.delegate.currentObjectContext];
    NSManagedObjectID * contactId = contact.objectID;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        Contact* contact = (Contact*)[context objectWithID:contactId];
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_delete_associated_data_question",nil), contact.nickName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_deleted_title", nil)
                                                         message: message
                                                 completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                     switch (buttonIndex) {
                                                         case 1:
                                                             // delete all group member contacts that are not friends or contacts in other group
                                                             [AppDelegate.instance deleteObject:contact inContext:context];
                                                             break;
                                                         case 0:
                                                             contact.relationshipState = kRelationStateKept;
                                                             // keep contact and chats
                                                             [contact updateNearbyFlag];
                                                             break;
                                                     }
                                                     [self.delegate saveContext:context];
                                                 }
                                               cancelButtonTitle: NSLocalizedString(@"contact_keep_data_button", nil)
                                               otherButtonTitles: NSLocalizedString(@"contact_delete_data_button",nil),nil];
        [alert show];
    }];
}

- (void) handleDeletionOfContact:(Contact*)contact withForce:(BOOL)force inContext:(NSManagedObjectContext*) context {

    if (!force && ((AppDelegate.instance.inNearbyMode && contact.isNearby) || [AppDelegate.instance isInspecting:contact])) {
        if (DEBUG_DELETION) NSLog(@"handleDeletionOfContact: is active nearby or being inspected, autokeeping contact id %@",contact.clientId);
        if (contact.groupMemberships.count == 0) {
            contact.relationshipState = kRelationStateKept;
        } else {
            contact.relationshipState = kRelationStateGroupFriend;
        }
        [contact updateNearbyFlag];
        return;
    }
    
    if ((contact.messages.count == 0 && contact.groupMemberships.count == 0 && contact.deliveriesSent.count == 0) || force) {
        // if there is nothing to save, delete right away and dont ask
        if (RELATIONSHIP_DEBUG || DEBUG_DELETION) NSLog(@"handleDeletionOfContact: nothing to save or kept, delete contact id %@",contact.clientId);
        if (!force) {
            [self removedAlertForContact:contact];
        }
        [AppDelegate.instance deleteObject:contact inContext:context];
        [AppDelegate.instance saveContext:context];
        return;
    }
    
    if (contact.groupMemberships.count == 0) {
        [self askForDeletionOfContact:contact];
    } else {
        contact.relationshipState = kRelationStateGroupFriend;
        [contact updateNearbyFlag];
        [self removedButKeptInGroupAlertForContact:contact];
    }
}


- (void) syncPresencesWithForce:(BOOL)force withCompletion:(GenericResultHandler)completion {
    NSDate * latestChange;
    if (force) {
        latestChange = [NSDate dateWithTimeIntervalSince1970:0];
    } else {
        latestChange = [self getLatestChangeDateForContactPresence];
    }

    // NSLog(@"latest date %@", latestChange);
    [self getPresences: latestChange presenceHandler:^(NSArray * changedPresences) {
        for (id presence in changedPresences) {
            // NSLog(@"updatePresences presence=%@",presence);
            [self presenceUpdated:presence];
        }
        //[self checkContactsWithCompletion:completion];
        [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self checkContactsWithCompletionContext:self.delegate.mainObjectContext inContext:context withCompletion:completion];
        }];
    }];
}


- (void) fetchKeyForContact:(Contact *)theContact withKeyId:(NSString*) theId withCompletion:(CompletionBlock)handler {
    [self.delegate saveContext:self.delegate.currentObjectContext];
    NSManagedObjectID * contactId = theContact.objectID;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        Contact * theContact = (Contact*)[context objectWithID:contactId];
        
        [self getKeyForClientId: theContact.clientId withKeyId:theId keyHandler:^(NSDictionary * keyRecord) {
            
            if (USE_VALIDATOR) [self validateObject: keyRecord forEntity:@"RPC_TalkKey_in"];  // TODO: Handle Validation Error
            
            if (keyRecord != nil) {
                if ([theId isEqualToString: keyRecord[@"keyId"]]) {
                    if (![keyRecord[@"keyId"] isEqualToString: theContact.publicKeyId] &&
                        theContact.verifiedKey != nil &&
                        [theContact.publicKey isEqualToData: theContact.verifiedKey])
                    {
                        // a verified key has been changed, warn about it
                        [HXOUI showAlertWithMessageAsync:@"key_verified_public_key_changed_message_format" withTitle: @"key_verified_public_key_changed_title" withArgument: theContact.nickName];
                    }
                    theContact.publicKeyString = keyRecord[@"key"];
                    theContact.publicKeyId = keyRecord[@"keyId"];
                    // NSLog(@"Key for contact updated: %@", theContact);
                    // NSLog(@"Received new public key for contact: %@", theContact.nickName);
                    [self.delegate saveDatabase];
                    if (handler != nil) handler(nil);
                } else {
                    NSLog(@"ERROR: key not updated, response keyid mismatch for contact id %@ nick %@", theContact.clientId, theContact.nickName);
                    NSString * myDescription = [NSString stringWithFormat:@"ERROR: key not updated, response keyid mismatch for contact: %@ nick %@", theContact.clientId, theContact.nickName];
                    NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9912 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                    if (handler != nil) handler(myError);
                }
            } else {
                // retry
                // [self fetchKeyForContact:theContact withKeyId:theId withCompletion:handler];
                NSLog(@"ERROR: could not fetch key with keyid %@ for contact id %@ nick %@", theId, theContact.clientId, theContact.nickName);
                NSString * myDescription = [NSString stringWithFormat:@"ERROR: key not fetch key with keyid %@ for contact: %@ nick %@", theId, theContact.clientId, theContact.nickName];
                NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9913 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                if (handler != nil) handler(myError);
            }
        }];
    }];
}

- (void) presenceUpdated:(NSDictionary *) thePresence {
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        if (USE_VALIDATOR) [self validateObject: thePresence forEntity:@"RPC_TalkPresence_in"];  // TODO: Handle Validation Error
        NSString * myClient = thePresence[@"clientId"];
        if ([myClient isEqualToString: [UserProfile sharedProfile].clientId]) {
            return;
        }
        @synchronized([self idLock:myClient]) {
            if (LOCKING_TRACE) NSLog(@"Entering synchronized presenceUpdated %@",myClient);
            BOOL newContact = NO;
            Contact * myContact = [self getContactByClientId:myClient inContext:context];
            if (myContact == nil) {
                // NSLog(@"clientId unknown, creating new contact for client: %@", myClient);
                myContact = [NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext: context];
                myContact.type = [Contact entityName];
                myContact.clientId = myClient;
                myContact.relationshipState = kRelationStateNone;
                myContact.relationshipLastChanged = [NSDate dateWithTimeIntervalSince1970:0];
                myContact.avatarURL = @"";
                [self checkRelationsipStateForGroupMembershipOfContact:myContact];
                newContact = YES;
            }
            myContact.lastUpdateReceived = [NSDate date];
            
            BOOL newFriend = NO;
            
            if (myContact) {
                NSString * newNickName = thePresence[@"clientName"];
                if (myContact.nickName == nil && newNickName.length > 0 && myContact.isFriend) {
                    newFriend = YES;
                }
                myContact.nickName = newNickName;
                myContact.status = thePresence[@"clientStatus"];
                myContact.connectionStatus = thePresence[@"connectionStatus"];
                if (myContact.connectionStatus == nil) { // TODO: this no longer happens, we need another server-side notfication in order to determine if presence comes via a group relationship
                    // is a group
                    myContact.connectionStatus = @"group";
                    myContact.relationshipState = kRelationStateGroupFriend;
                }
                if (![myContact.publicKeyId isEqualToString: thePresence[@"keyId"]] || ((self.firstConnectionAfterCrashOrUpdate  || _uncleanConnectionShutdown) || [self fullSync])) {
                    // fetch key
                    [self fetchKeyForContact: myContact withKeyId:thePresence[@"keyId"] withCompletion:^(NSError *theError) {
                        // [self checkGroupKeysForGroupMembershipOfContact:myContact];
                    }];
                }
                [self updateAvatarForContact:myContact forAvatarURL:thePresence[@"avatarUrl"]];
                
                myContact.presenceLastUpdatedMillis = thePresence[@"timestamp"];
                // NSLog(@"presenceUpdated, contact = %@", myContact);
                if (newContact) {
                    [self checkIfNeedToPresentInvitationForGroupAfterNewPresenceOf:myContact];
                } else {
                    [myContact updateNearbyFlag];
                }
            } else {
                NSLog(@"presenceUpdated: unknown clientId failed to create new contact for id: %@", myClient);
            }
            [self.delegate saveContext:context];
            if (newFriend) {
                [self newFriendAlertForContact:myContact];
            }
        }
        if (LOCKING_TRACE) NSLog(@"Done synchronized presenceUpdated %@",myClient);
    }];
}


- (void) presenceModified:(NSDictionary *) thePresence {
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
        NSString * myClient = thePresence[@"clientId"];
        if ([myClient isEqualToString: [UserProfile sharedProfile].clientId]) {
            return;
        }
        Contact * myContact = [self getContactByClientId:myClient inContext:context];
        if (myContact == nil) {
            // no presence modification for unknown contacts;
            return;
        }
        myContact.lastUpdateReceived = [NSDate date];
        
        NSString * newNickName = thePresence[@"clientName"];
        if (newNickName != nil && newNickName.length > 0) {
            myContact.nickName = newNickName;
        }
        
        NSString * newStatus = thePresence[@"clientStatus"];
        if (newStatus != nil) {
            myContact.status = newStatus;
        }
        
        NSString * newConnectionStatus = thePresence[@"connectionStatus"];
        if (newConnectionStatus != nil) {
            myContact.connectionStatus = newConnectionStatus;
        }
        
        NSString * newKeyId = thePresence[@"keyId"];
        if (newKeyId != nil) {
            if (![myContact.publicKeyId isEqualToString: newKeyId]) {
                // fetch key
                [self fetchKeyForContact: myContact withKeyId:newKeyId withCompletion:^(NSError *theError) {
                    // [self checkGroupKeysForGroupMembershipOfContact:myContact];
                }];
            }
        }
        
        NSString * newAvatarURL = thePresence[@"avatarUrl"];
        if (newAvatarURL != nil) {
            [self updateAvatarForContact:myContact forAvatarURL:newAvatarURL];
        }
        
        NSNumber * newTimeStamp = thePresence[@"timestamp"];
        if (newTimeStamp != nil) {
            NSLog(@"WARNING: presenceModified receiced timestamp for contact id = %@", myContact.clientId);
            myContact.presenceLastUpdatedMillis = newTimeStamp;
            
        }
        //[self.delegate saveDatabase];
    }];
}

- (void) updateAvatarForContact:(Contact*)myContact forAvatarURL:(NSString*)theAvatarURL {
    [self.delegate saveContext:self.delegate.currentObjectContext];
    NSManagedObjectID * contactId = myContact.objectID;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        Contact * myContact = (Contact*)[context objectWithID:contactId];
        if (![myContact.avatarURL isEqualToString: theAvatarURL]) {
            if (theAvatarURL.length) {
                if (CONNECTION_TRACE) {NSLog(@"updateAvatarForContact, downloading avatar from URL %@", theAvatarURL);}
                
                [HXOBackend downloadDataFromURL:theAvatarURL inQueue:_avatarDownloadQueue withCompletion:^(NSData * data, NSError * error) {
                    NSData * myNewAvatar = data;
                    if (myNewAvatar != nil && error == nil) {
                        // NSLog(@"presenceUpdated, avatar downloaded");
                        myContact.avatar = myNewAvatar;
                        myContact.avatarURL = theAvatarURL;
                    } else {
                        NSLog(@"presenceUpdated, avatar download for contact '%@' id ‘%@' of URL %@ failed, error=%@ reason=%@", myContact.nickName, myContact.clientId, theAvatarURL, error.localizedDescription,error.localizedFailureReason);
                    }
                }];
            } else {
                // no avatar
                if (CONNECTION_TRACE) {NSLog(@"updateAvatarForContact, setting nil avatar");}
                myContact.avatar = nil;
                myContact.avatarURL = @"";
            }
        }
    }];
}

//  void alertUser(String text);
- (void) alertUser:(NSArray*) param {
    NSString * title = param[0];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                     message: nil
                                                    delegate: nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
    
}

#pragma mark - Group related rpc interfaces: notifications

//  void groupUpdated(TalkGroup group);
- (void) groupUpdated:(NSArray*) group_param {
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self updateGroupHere: group_param[0] inContext:context];
    }];
}

// void groupMemberUpdated(TalkGroupMember groupMember);
- (void) groupMemberUpdated:(NSArray*) groupMember_param {
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self updateGroupMemberHere: groupMember_param[0] inContext:context];
    }];
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
    Group * group = (Group*)[NSEntityDescription insertNewObjectForEntityForName: [Group entityName] inManagedObjectContext:self.delegate.mainObjectContext];
    if (group == nil) {
        NSLog(@"failed to insert group into context");
        abort();
    }
    group.type = [Group entityName];
    group.groupTag = [NSString stringWithUUID];
    //group.groupKey = [Crypto random256BitKey];
    
    GroupMembership * myMember = (GroupMembership*)[NSEntityDescription insertNewObjectForEntityForName: [GroupMembership entityName] inManagedObjectContext:self.delegate.mainObjectContext];
    //AUTOREL [group addMembersObject:myMember];
    myMember.group = group;
    //AUTOREL group.myGroupMembership = myMember;
    myMember.ownGroupContact = group;
    myMember.contact = group;
    myMember.role = @"admin";
    myMember.state = @"joined";
    [group generateNewGroupKey];

    [self.delegate saveDatabase];
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
             [self.delegate saveDatabase];
             handler(group);
             if (GROUP_DEBUG) NSLog(@"createGroup() key = %@", group.groupKey);
             if (GROUP_DEBUG) NSLog(@"createGroup() returned groupId: %@", responseOrError);
         } else {
             NSLog(@"createGroup() failed: %@", responseOrError);
             handler(nil);
         }
     }];
}

// String updateEnvironment(TalkEnvironment environment);
- (void) updateEnvironment:(HXOEnvironment *) environment withHandler:(UpdateEnvironmentHandler)handler {
    NSDictionary * environmentDict = [environment asDictionary];
    
    // [self validateObject: groupDict forEntity:@"RPC_Group_out"]; // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"updateEnvironment" withParams: @[environmentDict]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSString * groupId = (NSString*)responseOrError;
             environment.groupId = groupId;
             [self.delegate saveDatabase];
             handler(groupId);
             if (GROUP_DEBUG) NSLog(@"updateEnvironment() returned groupId: %@", responseOrError);
         } else {
             NSLog(@"updateEnvironment() failed: %@", responseOrError);
             handler(nil);
         }
     }];
}

// void destroyEnvironment(String type);
- (void) destroyEnvironmentType:(NSString*)type withHandler:(GenericResultHandler)handler {
    
    [_serverConnection invoke: @"destroyEnvironment" withParams: @[type]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             handler(YES);
             if (GROUP_DEBUG) NSLog(@"destroyEnvironment() returned success");
         } else {
             NSLog(@"destroyEnvironment() failed: %@", responseOrError);
             handler(NO);
         }
     }];
}

// get the list of all groups on the server I am a member of
//TalkGroup[] getGroups(Date lastKnown);
- (void) getGroups:(NSDate *)lastKnown groupsHandler:(GroupsHandler) handler {
    NSNumber * lastKnownMillis = [HXOBackend millisFromDate:lastKnown];
    [_serverConnection invoke: @"getGroups" withParams: @[lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"getGroups(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getGroups(): failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

-(BOOL)fullSync {
    return [[[HXOUserDefaults standardUserDefaults] objectForKey:@"fullSync"] boolValue];
}

-(BOOL)quickStart {
    return [[[HXOUserDefaults standardUserDefaults] objectForKey:@"quickStart"] boolValue];
}

- (void) syncGroupsWithForce:(BOOL)forceAll withCompletionContext:(NSManagedObjectContext*)completionContext withCompletion:(GenericResultHandler)completion {
    NSDate * latestChange;
    if (forceAll) {
        latestChange = [NSDate dateWithTimeIntervalSince1970:0];
    } else {
        latestChange = [self getLatestChangeDateForGroups];
    }
    
    [self getGroups: latestChange groupsHandler:^(NSArray * changedGroups) {
        [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
            if (GROUP_DEBUG) NSLog(@"getGroups result = %@",changedGroups);
            if ([changedGroups isKindOfClass:[NSArray class]]) {
                BOOL ok = YES;
                for (NSDictionary * groupDict in changedGroups) {
                    
                    BOOL stateOk =[self updateGroupHere: groupDict inContext:context];
                    Group * group = [self getGroupById:groupDict[@"groupId"] inContext:context];
                    if (group != nil) {
                        [self makeSureAvatarUploadedForGroup:group withCallingContext:context withCompletion:^(NSError *theError) {
                            if (CHECK_URL_TRACE) NSLog(@"makeSureAvatarUploadedForGroup %@ error=%@",group.nickName,theError);
                        }];
                        if (forceAll) {
                            [self getGroupMembers:group lastKnown:[NSDate dateWithTimeIntervalSince1970:0] withCompletionContext:context inContext:context withCompletion:nil];
                        } else {
                            [self getGroupMembers:group lastKnown:[group latestMemberChangeDate] withCompletionContext:context inContext:context withCompletion:nil];
                        }
                    }
                    ok = ok && stateOk;
                }
            }
            [self checkGroupMembershipsWithCompletionContext:completionContext inContext:context withCompletion:completion];
        }];
    }];
}

-(void) mergeGroups:(NSArray*)myGroups intoGroup:(Group*)targetGroup inContext:(NSManagedObjectContext *)context {
    NSArray * groups = [NSArray arrayWithArray:myGroups];
    for (int i = 0; i < groups.count;++i) {
        Group * src = groups[i];
        if (![src isEqual:targetGroup]) {
            NSLog(@"mergeGroups: merging group %@ to %@", src.clientId, targetGroup.clientId);
            NSSet * messages = [NSSet setWithSet: src.messages];
            for (HXOMessage * message in messages) {
                Delivery * delivery = message.deliveries.anyObject;
                message.contact = targetGroup;
                delivery.group = targetGroup;
            }
        }
    }
    for (int i = 0; i < groups.count;++i) {
        Group * src = groups[i];
        if (![src isEqual:targetGroup]) {
            NSLog(@"mergeGroups: deleting group %@", src.clientId);
            [self.delegate deleteObject:src inContext:context];
        }
    }
    [self.delegate saveContext:context];
}

-(Group*)findInspectedNearbyGroupInContext:(NSManagedObjectContext *)context {
    NSArray * groups = [self getNearbyGroupsInContext:context];
    for (Group * group in groups) {
        if ([self.delegate isInspecting:group]) {
            return group;
        }
    }
    return nil;
}

-(NSArray*) getNearbyGroupsInContext:(NSManagedObjectContext *)context{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Group" inManagedObjectContext: context];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"type == 'Group' AND groupType == 'nearby'" ]];
    
    NSError *error;
    NSArray *groups = [context executeFetchRequest:fetchRequest error:&error];
    if (groups == nil)
    {
        NSLog(@"Fetch request for 'checkGroupMemberships' failed: %@", error);
        abort();
    }
    return groups;
}

-(Group*)singleNearbyGroupWithId:(NSString*)groupId inContext:(NSManagedObjectContext *)context {
    NSLog(@"singleNearbyGroupWithId: %@", groupId);
    NSArray * groups = [self getNearbyGroupsInContext:context];
    NSLog(@"singleNearbyGroupWithId: %@, found %d nearby groups", groupId, groups.count);
    if (groups.count > 0) {
        Group * inspectedGroup = [self findInspectedNearbyGroupInContext:context];
        if (inspectedGroup == nil) {
            inspectedGroup = groups[0];
        }
        NSLog(@"singleNearbyGroupWithId: changing group %@ to %@", inspectedGroup.clientId, groupId);
        [inspectedGroup changeIdTo:groupId];
        
        if (groups.count > 1) {
            [self mergeGroups: groups intoGroup:inspectedGroup inContext:context];
        }
        return inspectedGroup;
    }
    return nil;
}

- (BOOL) updateGroupHere: (NSDictionary*) groupDict inContext:(NSManagedObjectContext*) context {
    //[self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
    if (GROUP_DEBUG) NSLog(@"updateGroupHere with %@",groupDict);
    
    NSString * groupId = groupDict[@"groupId"];
    
    @synchronized([self idLock:groupId]) {
        if (LOCKING_TRACE) NSLog(@"Entering synchronized updateGroupHere %@",groupId);
        Group * group = [self getGroupById: groupId orByTag:groupDict[@"groupTag"] inContext:context];
        
        NSString * groupState = groupDict[@"state"];
        if (groupState == nil) {
            NSLog(@"Error: group without group state, dict=%@", groupDict);
            return NO;
        }
        if (group != nil) {
            group.lastUpdateReceived = [NSDate date];
        }
        
        if ([groupState isEqualToString:@"none"]) {
            if (group != nil && ![group.groupState isEqualToString: kRelationStateKept] && ![group.groupState isEqualToString:@"none"] && !group.isNearbyGroup) {
                if (GROUP_DEBUG) NSLog(@"updateGroupHere: handleDeletionOfGroup %@", group.clientId);
                [group updateWithDictionary: groupDict];
                [self handleDeletionOfGroup:group inContext:context];
                if (GROUP_DEBUG) NSLog(@"updateGroupHere: end processing of a removed group");
            }
            return YES;
        }
        
        if (group == nil) {
            // handle nearby group merging
            if ([@"nearby" isEqualToString: groupDict[@"groupType"]]) {
                group = [self singleNearbyGroupWithId:groupId inContext:context];
            }
            if (group == nil) {
                group = (Group*)[NSEntityDescription insertNewObjectForEntityForName: [Group entityName] inManagedObjectContext:context];
                group.type = [Group entityName];
                group.clientId = groupId;
                group.lastUpdateReceived = [NSDate date];
                if (GROUP_DEBUG) NSLog(@"updateGroupHere: created a new group with id %@",groupId);
            }
        }
        
        [group updateWithDictionary: groupDict];
        
        if (!group.isKeptGroup && group.isKeptRelation) {
            group.relationshipState = nil;
        }
        
        // download group avatar if changed
        if (!group.iAmAdmin && groupDict[@"groupAvatarUrl"] != group.avatarURL) {
            [self updateAvatarForContact:group forAvatarURL:groupDict[@"groupAvatarUrl"]];
        }
        
        [self.delegate saveContext:context];
        if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupHere %@",groupId);
        return YES;
    }
}

// update a group on the server (as admin)
// void updateGroup(TalkGroup group);
- (void) updateGroup:(Group *) group {
    [self uploadAvatarIfNeededForGroup:group withCompletion:^(NSError *theError) {
        if (theError == nil) {
            NSMutableDictionary * groupDict = [group rpcDictionary];
            if (group.avatarURL != nil) {
                groupDict[@"groupAvatarUrl"]=group.avatarURL;
            } else {
                groupDict[@"groupAvatarUrl"]=@"";
            }
            
            // [self validateObject: groupDict forEntity:@"RPC_Group_out"]; // TODO: Handle Validation Error
            
            [_serverConnection invoke: @"updateGroup" withParams: @[groupDict]
                           onResponse: ^(id responseOrError, BOOL success)
             {
                 if (success) {
                     if (GROUP_DEBUG) NSLog(@"updateGroup() ok: %@", responseOrError);
                 } else {
                     NSLog(@"updateGroup() failed: %@", responseOrError);
                 }
             }];
        } else {
            // retry after some time
            double delayInSeconds = 10.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self updateGroup:group];
            });
        }
    }];
}

// void deleteGroup(String groupId);
- (void) deleteGroup:(Group *) group onDeletion:(GroupHandler)handler {
    if (group.clientId == nil) {
        NSLog(@"deleteGroup: group.clientId is nil");
        handler(nil);
        return;
    }
    [_serverConnection invoke: @"deleteGroup" withParams: @[group.clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"deleteGroup() ok: got result: %@", responseOrError);
            handler(group);
        } else {
            NSLog(@"deleteGroup(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

// void joinGroup(String groupId);
- (void) joinGroup:(Group *) group onJoined:(GroupHandler)handler {
    if (group.clientId == nil) {
        NSLog(@"joinGroup: group.clientId is nil");
        handler(nil);
        return;
    }
    [_serverConnection invoke: @"joinGroup" withParams: @[group.clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"joinGroup() ok: got result: %@", responseOrError);
            handler(group);
        } else {
            NSLog(@"joinGroup(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

// void leaveGroup(String groupId);
- (void) leaveGroup:(Group *) group onGroupLeft:(GroupHandler)handler {
    if (group.clientId == nil) {
        NSLog(@"leaveGroup: group.clientId is nil");
        handler(nil);
        return;
    }
    [_serverConnection invoke: @"leaveGroup" withParams: @[group.clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"leaveGroup() ok: got result: %@", responseOrError);
            handler(group);
        } else {
            NSLog(@"leaveGroup(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

//TalkGroupMember[] getGroupMembers(String groupId, Date lastKnown);
- (void) getGroupMembers:(Group *)group lastKnown:(NSDate*) lastKnown membershipsHandler:(MembershipsHandler)handler {
    NSNumber * lastKnownMillis = [HXOBackend millisFromDate:lastKnown];
    [_serverConnection invoke: @"getGroupMembers" withParams: @[group.clientId,lastKnownMillis] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"getGroupMembers(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getGroupMembers(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) getGroupMembers:(Group *)group lastKnown:(NSDate *)lastKnown
   withCompletionContext:(NSManagedObjectContext*)completionContext
               inContext:(NSManagedObjectContext*)context
          withCompletion:(DoneBlock)completion
{
    [self getGroupMembers: group lastKnown:lastKnown membershipsHandler:^(NSArray * changedMembers) {
        for (NSDictionary * memberDict in changedMembers) {
            [self updateGroupMemberHere: memberDict inContext:context];
        }
        if (completion) {
            if ([completionContext isEqual:context]) {
                completion();
            } else {
                [completionContext performBlock:^{
                    completion();
                }];
            }
        }
    }];
}

// Boolean[] isMemberInGroups(String[] groupIds);
- (void) checkGroupMembershipsWithCompletionContext:(NSManagedObjectContext*)completionContext inContext:(NSManagedObjectContext*)context withCompletion:(GenericResultHandler)completion {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Group" inManagedObjectContext: context];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"type == 'Group' AND groupState != 'kept'" ]];
    
    NSError *error;
    NSArray *groupArray = [context executeFetchRequest:fetchRequest error:&error];
    if (groupArray == nil)
    {
        NSLog(@"Fetch request for 'checkGroupMemberships' failed: %@", error);
        abort();
    }
    NSMutableArray * groupsToCheck = [[NSMutableArray alloc]init];
    for (Group * group in groupArray) {
        [groupsToCheck addObject:group.clientId];
    }
    if (groupsToCheck.count > 0) {
        [self.delegate performInMainContext:^(NSManagedObjectContext *mainContext) {
            [_serverConnection invoke: @"isMemberInGroups" withParams: @[groupsToCheck] onResponse: ^(id responseOrError, BOOL success) {
                [context performBlock:^{
                    if (success) {
                        NSArray * memberFlags = responseOrError;
                        if (memberFlags.count != groupsToCheck.count || memberFlags.count != groupArray.count) {
                            NSLog(@"ERROR: isMemberInGroups(): return type mismatch, requested %d/%d flags, got %d",groupsToCheck.count,groupArray.count,memberFlags.count);
                            return;
                        }
                        for (int i = 0; i < memberFlags.count;++i) {
                            if ([memberFlags[i] boolValue] == NO) {
                                Group * group = groupArray[i];
                                NSLog(@"checkGroupMemberships: removing group with id: %@ nick: %@", group.clientId, group.nickName);
                                [self handleDeletionOfGroup:group inContext:context];
                            }
                        }
                    } else {
                        NSLog(@"isMemberInGroups(): failed: %@", responseOrError);
                    }
                    if (completion) {
                        if ([completionContext isEqual:context]) {
                            completion(success);
                        } else {
                            [completionContext performBlock:^{
                                completion(success);
                            }];
                        }
                    }
                }];
            }];
        }];
    } else {
        if (completion) {
            if ([completionContext isEqual:context]) {
                completion(YES);
            } else {
                [completionContext performBlock:^{
                    completion(YES);
                }];
            }
        }
    }
}


// Boolean[] isContactOf  (String[] clientIds);
- (void) checkContactsWithCompletionContext:(NSManagedObjectContext*)completionContext
                                  inContext:(NSManagedObjectContext*)context
                             withCompletion:(GenericResultHandler)completion
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext: context];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"type == 'Contact' AND relationshipState != 'kept'" ]];
    
    //[fetchRequest setPredicate: [NSPredicate predicateWithFormat:@"type == 'Contact' AND (relationshipState == 'friend' OR relationshipState == 'blocked' OR relationshipState == 'groupfriend' OR relationshipState == 'invited' OR relationshipState == 'invitedMe')" ]];
    
    NSError *error;
    NSArray *contactArray = [context executeFetchRequest:fetchRequest error:&error];
    if (contactArray == nil)
    {
        NSLog(@"Fetch request for 'checkContacts' failed: %@", error);
        abort();
    }
    NSMutableArray * contactsToCheck = [[NSMutableArray alloc]init];
    for (Contact * contact in contactArray) {
        [contactsToCheck addObject:contact.clientId];
    }
    if (contactsToCheck.count > 0) {
        [_serverConnection invoke: @"isContactOf" withParams: @[contactsToCheck] onResponse: ^(id responseOrError, BOOL success) {
            if (success) {
                NSArray * contactFlags = responseOrError;
                if (contactFlags.count != contactsToCheck.count || contactFlags.count != contactArray.count) {
                    NSLog(@"ERROR: isContactOf(): return type mismatch, requested %d/%d flags, got %d",contactsToCheck.count,contactArray.count,contactFlags.count);
                    return;
                }
                for (int i = 0; i < contactFlags.count;++i) {
                    if ([contactFlags[i] boolValue] == NO) {
                        Contact * contact = contactArray[i];
                        NSLog(@"checkContacts: removing contact with id: %@ nick: %@", contact.clientId, contact.nickName);
                        [self handleDeletionOfContact:contact withForce:NO inContext:context];
                    }
                }
            } else {
                NSLog(@"isContactOf(): failed: %@", responseOrError);
            }
            if (completion) {
                if ([completionContext isEqual:context]) {
                    completion(success);
                } else {
                    [completionContext performBlock:^{
                        completion(success);
                    }];
                }
            }
        }];
    } else {
        if (completion) {
            if ([completionContext isEqual:context]) {
                completion(YES);
            } else {
                [completionContext performBlock:^{
                    completion(YES);
                }];
            }
        }
    }
}


//TalkGroup getGroup(String groupId);
- (void) getGroup:(NSString *)groupId onResult:(ObjectResultHandler)handler {
    [_serverConnection invoke: @"getGroup" withParams: @[groupId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"getGroup(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getGroup(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) getGroup:(Group *)group {
    [self getGroup: group.clientId onResult:^(NSDictionary * groupDict) {
        if (groupDict) {
            [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
                [self updateGroupHere:groupDict inContext:context];
            }];
        }
    }];
}

//TalkGroupMember[] getGroupMembers(String groupId, Date lastKnown);
- (void) getGroupMember:(NSString *)groupId clientId:(NSString*)clientId onResult:(ObjectResultHandler)handler {
    [_serverConnection invoke: @"getGroupMember" withParams: @[groupId,clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            if (GROUP_DEBUG) NSLog(@"getGroupMember(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"getGroupMember(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) getGroupMember:(GroupMembership *)member {
    [self getGroupMember:member.group.clientId clientId:member.contactClientId onResult:^(NSDictionary *memberDict) {
        if (memberDict != nil) {
            [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
                [self updateGroupMemberHere: memberDict inContext:context];
            }];
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

- (Group*) createLocalGroup: (NSString*) groupId withState:(NSString*)groupState inContext:(NSManagedObjectContext*)context {
    Group * group = (Group*)[NSEntityDescription insertNewObjectForEntityForName: [Group entityName] inManagedObjectContext:context];
    group.type = [Group entityName];
    group.clientId = groupId;
    group.groupState = groupState;
    group.nickName = @"temporary";
    if (GROUP_DEBUG) NSLog(@"createLocalGroup: created a new group with id %@",groupId);
    return group;
}

- (void) updateGroupMemberHere: (NSDictionary*) groupMemberDict inContext:(NSManagedObjectContext*)context{
    //[self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
    
    NSString * groupId = groupMemberDict[@"groupId"];
    @synchronized([self idLock:groupId]) {
        if (LOCKING_TRACE) NSLog(@"Entering synchronized updateGroupMemberHere %@",groupId);
        Group * group = [self getGroupById: groupId inContext:context];
        if (group == nil) {
            if ([groupMemberDict[@"state"] isEqualToString:@"none"] || [groupMemberDict[@"state"] isEqualToString:@"groupRemoved"]) {
                if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r1) %@",groupId);
                return;
            } else {
                if ([@"nearbyMember" isEqualToString: groupMemberDict[@"role"]]) {
                    group = [self singleNearbyGroupWithId:groupId inContext:context];
                }
                if (group == nil) {
                    group = [self createLocalGroup:groupMemberDict[@"groupId"] withState:@"incomplete" inContext:context];
                }
            }
        }
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere with %@",groupMemberDict);
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere found group nick %@ id %@",group.nickName, group.clientId);
        
        NSString * memberClientId = groupMemberDict[@"clientId"];
        Contact * memberContact = [self getContactByClientId:memberClientId inContext:context];
        
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere getContactByClientId %@ returned group contact nick %@ id %@",memberClientId,memberContact.nickName,memberContact.clientId);
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere own clientId is %@",[UserProfile sharedProfile].clientId);
        
        if (memberContact == nil && ![[UserProfile sharedProfile].clientId isEqualToString:memberClientId]) {
            // There is no contact for this clientId, and it is not us
            if ([groupMemberDict[@"state"] isEqualToString:@"none"] || [groupMemberDict[@"state"] isEqualToString:@"groupRemoved"]) {
                // do not process unknown contacts with membership state ‘none'
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere not processing group member with state %@ id %@",groupMemberDict[@"state"], memberClientId);
                if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r2) %@",groupId);
                return;
            }
            // create new Contact because it does not exist and is not own contact
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: contact with clientId %@ unknown, creating contact with id",memberClientId);
            memberContact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:context];
            memberContact.type = [Contact entityName];
            memberContact.clientId = memberClientId;
            [self.delegate saveContext:context];
        }
        
        // look for member matching memberClientId in group members
        NSSet * theMemberSet = [group.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
            if (memberContact != nil) {
                if (obj.contact == nil) {
                    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: member without contact: %@:",obj);
                } else if (obj.contact.clientId == nil) {
                    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: contact without clientId: %@:",obj.contact);
                }
                BOOL result = [obj.contact.clientId isEqualToString: memberClientId];
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: filtering: result=%d, obj.contact.clientId1=%@, memberClientId=%@",result,obj.contact.clientId,memberClientId);
                return result;
            } else {
                // own contact
                BOOL result = [group isEqual:obj.contact];
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: filtering(nil contact): result=%d, group(.clientId)=%@, obj.contact(.clientId)=%@",result,group.clientId,obj.contact.clientId);
                return result;
            }
        }];
        if ([theMemberSet count] > 1) {
            NSLog(@"ERROR: duplicate members in group %@ with id %@",groupId,memberClientId);
            if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r3) %@",groupId);
            return;
        }
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: %d members, %d in filtered set",[group.members count], [theMemberSet count]);
        
        GroupMembership * myMembership = nil;
        if ([theMemberSet count] == 0) {
            if (![groupMemberDict[@"state"] isEqualToString:@"none"] && ![groupMemberDict[@"state"] isEqualToString:@"groupRemoved"]) {
                // create new member
                myMembership = (GroupMembership*)[NSEntityDescription insertNewObjectForEntityForName: [GroupMembership entityName] inManagedObjectContext:context];
                // memberContact will be nil for own membership
                if (memberContact == nil) {
                    // set pointer in group contact to our own membership
                    //group.myGroupMembership = myMembership;
                    myMembership.contact = group;
                    myMembership.ownGroupContact = group;
                    if (myMembership.contact == nil) {
                        NSLog(@"myMembership.contact is nil");
                        abort();
                    }
                    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: created new member for me with group as contact id %@",group.clientId);
                } else {
                    // set contact to other member contact
                    myMembership.contact = memberContact;
                    if (myMembership.contact == nil) {
                        NSLog(@"myMembership.contact is nil(2)");
                        abort();
                    }
                    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: created new member for contact id %@",memberContact.clientId);
                }
                //AUTOREL [group addMembersObject:myMembership];
                myMembership.group = group;
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: group has now %d members",[group.members count]);
            }
        } else {
            myMembership = [theMemberSet anyObject];
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: got member from memberset with nick %@ id %@",myMembership.contact.nickName, myMembership.contact.clientId);
        }
        
        if (myMembership == nil) {
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: no member found and not created, incoming member state must be 'none'");
            if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r4) %@",groupId);
            return;
        }
        // check for invitation
        BOOL weHaveBeenInvited = NO;
        if ([groupMemberDict[@"state"] isEqualToString:@"invited"] &&
            !myMembership.isInvited &&
            [group isEqual:myMembership.contact])
        {
            weHaveBeenInvited = YES;
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: weHaveBeenInvited");
        }
        
        BOOL someoneHasJoinedGroup = NO;
        if ([groupMemberDict[@"state"] isEqualToString:@"joined"] &&
            myMembership.isInvited &&
            ![group isEqual:myMembership.contact] &&                   // only if s.o. membership else has been updated
            group.myGroupMembership.isJoined) // only show when we habe already joined
        {
            someoneHasJoinedGroup = YES;
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: someoneHasJoinedGroup");
        }
        
        BOOL memberShipDeleted = NO;
        BOOL disinvited = NO;
        if ([group.groupState isEqualToString:@"exists"]) {
            if ([groupMemberDict[@"state"] isEqualToString:@"none"]/* && ![myMembership.state isEqualToString:@"none"]*/) {
                // someone has left the group or we have been kicked out of an existing group
                memberShipDeleted = YES;
                disinvited = myMembership.isInvited;
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: memberShipDeleted");
            }
        }
        
        // NSLog(@"groupMemberDict Dict: %@", groupMemberDict);
        [myMembership updateWithDictionary: groupMemberDict];
        
        [self checkRelationsipStateForGroupMembershipOfContact:memberContact];
        
        if (myMembership.isOwnMembership && groupMemberDict[@"encryptedGroupKey"] != nil) {
            // we got a new key
            [group copyKeyFromMember:myMembership];
        }
        
        if (memberContact != nil) {
            if (myMembership.group.groupType != nil && myMembership.group.isNearbyGroup && myMembership.isJoined) {
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: set contact nearby");
                memberContact.isNearbyTag = @"YES";
            } else {
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: set contact not nearby");
                memberContact.isNearbyTag = nil;
            }
        } else {
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: no memberContact yet");
        }
        
        [self.delegate saveContext:context];
        
        if (memberShipDeleted) {
            // delete member
            if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"updateGroupMemberHere: deleting member with state '%@', nick=%@", groupMemberDict[@"state"], memberContact.nickName);
            [self handleDeletionOfGroupMember:myMembership inGroup:group withContact:memberContact disinvited:disinvited inContext:context];
        } else {
            if (weHaveBeenInvited) {
                if (!group.shouldPresentInvitation) {
                    if (![self tryPresentInvitationIfPossibleForGroup:group withMemberShip:myMembership]) {
                        group.shouldPresentInvitation = true;
                    }
                }
            } else {
                if (group.shouldPresentInvitation) {
                    [self tryPresentInvitationIfPossibleForGroup:group withMemberShip:myMembership];
                }
                
            }
            if (someoneHasJoinedGroup) {
                [self groupJoinedAlertForGroupNamed:group.nickName withMemberNamed:memberContact.nickName];
            }
        }
        [context performBlock:^{
            NSManagedObjectID * groupId = group.objectID;
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                [context refreshObject: [context objectWithID:groupId] mergeChanges: YES];
            }];
        }];
        if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere %@",groupId);
    }
}

- (BOOL)tryPresentInvitationIfPossibleForGroup:(Group *) group withMemberShip:(GroupMembership*)myMembership {
    if (!group.isIncompleteGroup && group.hasAdmin) {
        [self invitationAlertForGroup:group withMemberShip:myMembership];
        return true;
    }
    return false;
}

- (void)checkIfNeedToPresentInvitationForGroup:(Group *)group {
    if (group.shouldPresentInvitation) {
        if ([self tryPresentInvitationIfPossibleForGroup:group withMemberShip:group.myGroupMembership]) {
            group.shouldPresentInvitation = false;
        }
    }
}

- (void)checkIfNeedToPresentInvitationForGroupAfterNewPresenceOf:(Contact *)contact {
    NSSet * memberShips = contact.groupMemberships;
    for (GroupMembership* m in memberShips) {
        [self checkIfNeedToPresentInvitationForGroup:m.group];
    }
}

- (void)handleDeletionOfGroupMember:(GroupMembership*)myMember inGroup:(Group*)group withContact:(Contact*)memberContact disinvited:(BOOL)disinvited inContext:(NSManagedObjectContext*) context{
    
    NSString * groupName = group.nickName;
    NSString * contactName = memberContact.nickName;

    if (![group isEqual:myMember.contact]) { // not us
        if (!disinvited) {
            // show group left alerts to all members if not a nearby group
            if (!group.isNearbyGroup) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self groupLeftAlertForGroupNamed:groupName withMemberNamed:contactName];
                });
            }
        } else {
            // show disinvitation only to admins or affected contacts
            if (group.iAmAdmin || [group isEqual:myMember.contact]) {
                [self groupDisinvitedAlertForGroupNamed:groupName withMemberNamed:contactName];
            }
        }
        if (memberContact.relationshipState == nil ||
            (!memberContact.isFriend && !memberContact.isBlocked && memberContact.groupMemberships.count == 1))
        {
            if (memberContact.messages.count > 0 || memberContact.deliveriesSent.count > 0) {
                if (!group.isNearbyGroup) {
                    [self askForDeletionOfContact:memberContact];
                }  else {
                    //autokeep
                    memberContact.relationshipState = kRelationStateKept;
                }
            } else {
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: deleting contact with clientId %@",memberContact.clientId);
                [AppDelegate.instance deleteObject:memberContact inContext:context];
            }
        }
        // delete group membership
        [AppDelegate.instance deleteObject:myMember inContext:context];
    } else {
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: we have been thrown out or have left group, deleting own contact clientId %@",memberContact.clientId);
        // we have been thrown out or left group
        if (!group.isKept) {
            if (group.messages.count == 0) {
                // show kicked message
                if (!disinvited) {
                    // show kicked from group alert if not a nearby group
                    if (![@"nearby" isEqualToString:group.groupType] ) {
                        [self groupKickedAlertForGroupNamed:groupName];
                    }
                } else {
                    [self groupDisinvitedAlertForGroupNamed:groupName];
                }
            }
            [self handleDeletionOfGroup:group inContext:context];
        }
    }
}

- (void) handleDeletionOfGroup:(Group*)group inContext:(NSManagedObjectContext*) context {
    
    if (group.isNearbyGroup) {
        if (group.messages.count > 0 || [AppDelegate.instance isInspecting:group]) {
            if (DEBUG_DELETION) NSLog(@"handleDeletionOfGroup: is nearby with messages, autokeeping group id %@",group.clientId);
            group.groupState = kRelationStateKept;
            group.relationshipState = kRelationStateKept;
            [self deleteInDatabaseAllMembersAndContactsofGroup:group inContext:context];
            [self.delegate saveContext:context];
            return;
        }
        if (DEBUG_DELETION) NSLog(@"handleDeletionOfGroup: is active nearby, autokeeping group id %@",group.clientId);
    }
    
    NSString * groupId = group.clientId;
    @synchronized(_pendingGroupDeletions) {
        if (![_pendingGroupDeletions containsObject:groupId]) {
            [_pendingGroupDeletions addObject:groupId];
            if (group.messages.count == 0) {
                // if theres nothing to save, delete right away and dont ask
                if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"handleDeletionOfGroup: nothing to save, delete group with name ‘%@' id %@",group.nickName, group.clientId);
                [self deleteInDatabaseAllMembersAndContactsofGroup:group inContext:context];
                [AppDelegate.instance deleteObject:group inContext:context];
                [self.delegate saveContext:context];
                [_pendingGroupDeletions removeObject:groupId];
                return;
            }
            
            [self.delegate saveContext:context];
            NSManagedObjectID * groupObjId = group.objectID;
            [self.delegate performInMainContext:^(NSManagedObjectContext *mainContext) {
                Group* group = (Group*)[context objectWithID:groupObjId];
                NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_deleted_message_format",nil), group.nickName];
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_deleted_title", nil)
                                                                 message: NSLocalizedString(message, nil)
                                                         completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                             switch (buttonIndex) {
                                                                 case 1:
                                                                     // delete all group member contacts that are not friends or contacts in other group
                                                                     [self deleteInDatabaseAllMembersAndContactsofGroup:group inContext:mainContext];
                                                                     // delete the group
                                                                     [AppDelegate.instance deleteObject:group inContext:mainContext];
                                                                     break;
                                                                 case 0:
                                                                     group.groupState = kRelationStateKept;
                                                                     group.relationshipState = kRelationStateKept;
                                                                     // keep group and chats
                                                                     break;
                                                             }
                                                             [self.delegate saveDatabase];
                                                             @synchronized(_pendingGroupDeletions) {
                                                                 [_pendingGroupDeletions removeObject:groupId];
                                                             }
                                                         }
                                                       cancelButtonTitle: NSLocalizedString(@"group_keep_data_button", nil)
                                                       otherButtonTitles: NSLocalizedString(@"group_delete_data_button",nil),nil];
                [alert show];
            }];
            
        } else {
            if (DEBUG_DELETION) NSLog(@"updateGroupHere: group deletion in progess for group id %@", group.clientId);
        }
    }
}

- (void) groupKickedAlertForGroupNamed:(NSString*)groupName {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * title = [NSString stringWithFormat: NSLocalizedString(@"group_kicked_title",nil), groupName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                         message: nil
                                                        delegate: nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    });
}

- (void) groupDisinvitedAlertForGroupNamed:(NSString*)groupName {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * title = [NSString stringWithFormat: NSLocalizedString(@"group_invite_removed_title",nil), groupName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                         message: nil
                                                        delegate: nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    });
}

- (void) groupJoinedAlertForGroupNamed:(NSString*)groupName withMemberNamed:(NSString*)memberName {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_joined_message_format",nil), memberName, groupName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_joined_title", nil)
                                                         message: NSLocalizedString(message, nil)
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    });
}

- (void) groupLeftAlertForGroupNamed:(NSString*)groupName withMemberNamed:(NSString*)memberName {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_left_message_format",nil), memberName, groupName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_left_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    });
}

- (void) groupDisinvitedAlertForGroupNamed:(NSString*)groupName withMemberNamed:(NSString*)memberName {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_invite_dismissed_message_format",nil), memberName, groupName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_invite_dismissed_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    });
}

//TODO THREADING
- (void) invitationAlertForGroup:(Group*)group withMemberShip:(GroupMembership*)member {
    if (group.presentingInvitation) {
        return;
    }
    group.presentingInvitation = YES;
    NSMutableArray * admins = [[NSMutableArray alloc] init];
    if (group.iAmAdmin) {
        [admins addObject: NSLocalizedString(@"group_admin_you", nil)];
    }
    [group.members enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        GroupMembership * member = (GroupMembership*) obj;
        if ([member.role isEqualToString: @"admin"] && member.contact != nil && ! [group isEqual:member.contact]) {
            [admins addObject: member.contact.nickName];
        }
    }];
    NSString * adminNames = [admins componentsJoinedByString:@", "];    
    
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_invite_message_format",nil), group.nickName, adminNames];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_invite_title", nil)
                                                     message: NSLocalizedString(message, nil)
                                                    completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                        switch (buttonIndex) {
                                                            case 0:
                                                                // join group
                                                                [self joinGroup:group onJoined:^(Group *group) {
                                                                    if (group != nil) {
                                                                        if (GROUP_DEBUG) NSLog(@"Joined group %@", group);
                                                                    } else {
                                                                        NSLog(@"ERROR: joinGroup %@ failed", group);
                                                                    }
                                                                    group.presentingInvitation = NO;
                                                                }];
                                                                break;
                                                            case 1:
                                                                // leave group
                                                                [self leaveGroup: group onGroupLeft:^(Group *group) {
                                                                    if (group != nil) {
                                                                        if (GROUP_DEBUG) NSLog(@"TODO: Group left, now destroy everything (except our friends)");
                                                                    } else {
                                                                        NSLog(@"ERROR: leaveGroup %@ failed", group);
                                                                    }
                                                                    group.presentingInvitation = NO;
                                                                }];
                                                                break;
                                                            case 2:
                                                                // do nothing
                                                                group.presentingInvitation = NO;
                                                                break;
                                                        }
                                                    }
                                           cancelButtonTitle: nil
                                           otherButtonTitles: NSLocalizedString(@"group_invite_join_group_btn_title", nil), NSLocalizedString(@"group_invite_decline_btn_title", nil), NSLocalizedString(@"group_invite_decide_later_btn_title", nil),nil];
    [alert show];
}

// delete all group member contacts that are not friends or contacts in other group
- (void)deleteInDatabaseAllMembersAndContactsofGroup:(Group*) group inContext:(NSManagedObjectContext*) context {
    if (GROUP_DEBUG  || DEBUG_DELETION) NSLog(@"deleteInDatabaseAllMembersAndContactsofGroup id %@ nick %@", group.clientId, group.nickName);
    // NSManagedObjectContext * moc = self.delegate.managedObjectContext;
    NSSet * groupMembers = group.members;
    if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"deleteInDatabaseAllMembersAndContactsofGroup found %d members", groupMembers.count);
    for (GroupMembership * member in groupMembers) {
        if (member.contact != nil && ![group isEqual:member.contact]) {
            if (!member.contact.isFriend &&
                !member.contact.isBlocked &&
                !member.contact.isKept &&
                member.contact.groupMemberships.count == 1)
            {
                if (member.contact.messages.count > 0 || member.contact.deliveriesSent > 0) {
                    // message in chat, ask for deletion
                    if (!member.group.isNearby) {
                        if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"ask for deletion of group member contact id %@", member.contact.clientId);
                        [self askForDeletionOfContact:member.contact];
                    } else {
                        // auto-keeping contact
                        if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"auto-keeping group member contact id %@", member.contact.clientId);
                        member.contact.relationshipState = kRelationStateKept;
                        [member.contact updateNearbyFlag];
                    }
                } else {
                    // we can throw out this member contact without asking
                    if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"deleting group member contact id %@", member.contact.clientId);
                    [AppDelegate.instance deleteObject:member.contact inContext:context];
                }
            } else {
                if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"updating nearby of group member contact id %@, nearby=%d", member.contact.clientId, member.contact.isNearby);
                [member.contact updateNearbyFlag];
                if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"updating nearby of group member contact id %@, nearby=%d", member.contact.clientId, member.contact.isNearby);
            }
        }
        // the membership can be deleted in any case, including our own membership
        if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"deleting group membership %@", member.objectID);
        [AppDelegate.instance deleteObject:member inContext:context];
    }
}

+ (BOOL) isZeroData:(NSData*)theData {
    const uint8_t * buffer = (uint8_t *)[theData bytes];
    for (int i=0; i < theData.length;++i) {
        if (buffer[i]!=0) return NO;
    }
    return YES;
}

+ (BOOL) isInvalid:(NSData*)theData {
    return theData == nil || [HXOBackend isZeroData:theData];
}

// void inviteGroupMember(String groupId, String clientId);
- (void) inviteGroupMember:(Contact *)contact toGroup:(Group*)group onDone:(GenericResultHandler)doneHandler{
    
    [_serverConnection invoke: @"inviteGroupMember" withParams: @[group.clientId,contact.clientId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             if (GROUP_DEBUG) NSLog(@"inviteGroupMember succeeded groupId: %@, clientId:%@",group.clientId,contact.clientId);
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
- (void) removeGroupMember:(GroupMembership *)member onDeletion:(GroupMemberDeleted)deletionHandler{

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

#ifndef USE_MEMBERKEY_PROTOCOL_V2
// void updateGroupKey(String groupId, String clientId, String key);
- (void) updateGroupKey:(GroupMembership *)member onSuccess:(GroupMemberChanged)changedHandler{
    
    [_serverConnection invoke: @"updateGroupKey" withParams: @[member.group.clientId,member.contact.clientId,member.contact.publicKeyId,member.cipheredGroupKeyString]
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
#endif

// void updateMyGroupKey(String groupId,String sharedKeyId, String sharedKeyIdSalt, String publicKeyId, String cryptedSharedKey);
- (void) updateMyGroupKey:(GroupMembership *)member onSuccess:(GroupMemberChanged)changedHandler {
    
    [_serverConnection invoke: @"updateMyGroupKey" withParams: @[member.group.clientId,member.sharedKeyId, member.sharedKeyIdSalt, member.contact.publicKeyId,member.cipheredGroupKeyString]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             //NSLog(@"updateGroupKey succeeded groupId: %@, clientId:%@",member.group.clientId,member.contact.clientId);
             changedHandler(member);
         } else {
             NSLog(@"updateMyGroupKey() failed: %@", responseOrError);
             changedHandler(nil);
         }
     }];
}

// String[] getEncryptedGroupKeys(String groupId, String sharedKeyId, String sharedKeyIdSalt, String[] clientIds, String[] publicKeyIds);
- (void) getEncryptedGroupKeys:(NSArray*)params withResponder:(ResultBlock)responder {
    
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
    
        id failed = @[];
        
        if (params.count != 5) {
            NSLog(@"getEncryptedGroupKeys() bad number of argument in params: %@, expected 5, got %d", params, params.count);
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];        }
        
        NSString * groupId = params[0];
        NSString * sharedKeyId = params[1];
        NSString * sharedKeyIdSalt = params[2];
        NSArray * clientIds = params[3];
        NSArray * publicKeyIds = params[4];
        
        if (groupId.length == 0 || sharedKeyId.length == 0 || sharedKeyIdSalt.length == 0 ||
            clientIds.count == 0 || publicKeyIds.count == 0 || clientIds.count != publicKeyIds.count)
        {
            NSLog(@"getEncryptedGroupKeys() missing or invalid argument in params: %@", params);
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
        }
        Group * group = [self getGroupById: groupId inContext:context];
        if (group == nil) {
            NSLog(@"getEncryptedGroupKeys() unknown group with id : %@", groupId);
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
        }
        if (![group.groupState isEqualToString:@"exists"]) {
            NSLog(@"getEncryptedGroupKeys() group not in state exist, id: %@", groupId);
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
        }
        NSString * newSharedKeyId = nil;
        NSString * newSharedKeyIdSalt = nil;
        if ([sharedKeyId isEqualToString:@"RENEW"]) {
            [group generateNewGroupKey];
            newSharedKeyId = group.sharedKeyIdString;
            newSharedKeyIdSalt = group.sharedKeyIdSaltString;
        } else {
            if (![sharedKeyId isEqualToString:group.sharedKeyIdString] ||
                ![sharedKeyIdSalt isEqualToString:group.sharedKeyIdSaltString] )
            {
                NSLog(@"getEncryptedGroupKeys() I have not the requested group key for group: %@ with sharedKeyId %@ and salt %@", groupId,sharedKeyId,sharedKeyIdSalt);
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
            }
        }
        
        NSMutableArray * contacts = [NSMutableArray new];
        for (int i = 0; i < clientIds.count;++i) {
            Contact * contact = nil;
            if ([clientIds[i] isEqualToString:UserProfile.sharedProfile.clientId]) {
                contact = (id)UserProfile.sharedProfile;
            } else {
                contact = [self getContactByClientId:clientIds[i] inContext:context];
            }
            if (contact == nil) {
                NSLog(@"getEncryptedGroupKeys() don't know contact id: %@", clientIds[i]);
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
            }
            if (!contact.hasPublicKey) {
                NSLog(@"getEncryptedGroupKeys() I have no public key for contact id: %@", clientIds[i]);
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
            }
            if (![contact.publicKeyId isEqualToString:publicKeyIds[i]]) {
                NSLog(@"getEncryptedGroupKeys() I have not the requested public key %@ for contact id: %@", publicKeyIds[i], clientIds[i]);
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
            }
            [contacts addObject:contact];
        }
        // ok, now we have all the ingredients to perform the request and can do the heavy lifting
        NSMutableArray * result = [NSMutableArray new];
        CCRSA * rsa = [CCRSA sharedInstance];
        for (int i = 0; i < clientIds.count;++i) {
            Contact * contact = (Contact*)contacts[i];
            SecKeyRef myReceiverKey = [contact getPublicKeyRef];
            NSData * keyBox = [rsa encryptWithKey:myReceiverKey plainData:group.groupKey];
            if (keyBox == nil) {
                NSLog(@"#ERROR: getEncryptedGroupKeys() Encryption failed for key %@ contact id: %@", publicKeyIds[i], clientIds[i]);
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
            }
            [result addObject:[keyBox asBase64EncodedString]];
        }
        if (newSharedKeyId != nil && newSharedKeyIdSalt != nil) {
            [result addObject:newSharedKeyId];
            [result addObject:newSharedKeyIdSalt];
        }
        [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
            responder(result);
        }];
    }];
}

#pragma mark - Attachment upload and download

- (void) flushPendingFiletransfers {
    [self uploadAvatarIfNeededWithCompletion:^(BOOL didIt) {
        if (didIt) {
            [self modifyPresenceAvatarURLWithHandler:nil];
        }
    }];
    [self flushPendingAttachmentUploads];
    [self flushPendingAttachmentDownloads];
    [self checkTransferQueues];
}

- (NSArray *) pendingAttachmentUploads {
    // NSLog(@"flushPendingAttachmentUploads");
    // fetch all not yet transferred uploads
    NSDictionary * vars = @{ @"max_retries" : [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentUploadRetries]};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"AttachmentsNotUploaded" substitutionVariables: vars];
    NSError *error;
    NSArray *unfinishedAttachments = [self.delegate.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (unfinishedAttachments == nil)
    {
        NSLog(@"Fetch request 'AttachmentsNotUploaded' failed: %@", error);
        abort();
    }
    if (TRANSFER_DEBUG) NSLog(@"flushPendingAttachmentUploads found %d unfinished uploads", [unfinishedAttachments count]);
    NSMutableArray * pendingAttachments = [[NSMutableArray alloc]init];
    for (Attachment * attachment in unfinishedAttachments) {
        AttachmentState attachmentState = attachment.state;
        if (attachmentState == kAttachmentWantsTransfer ||
            attachmentState == kAttachmentUploadIncomplete)
        {
            [pendingAttachments enqueue:attachment];
        }
    }
    return pendingAttachments;
}

- (void) flushPendingAttachmentUploads {
    NSArray * pendingAttachments = [self pendingAttachmentUploads];
    for (Attachment * attachment in pendingAttachments) {
        [self enqueueUploadOfAttachment:attachment];
    }
}

- (NSArray *) pendingAttachmentDownloads {
    // NSLog(@"flushPendingAttachmentDownloads");
    // fetch all not yet transferred uploads
    NSDictionary * vars = @{ @"max_retries" : [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentDownloadRetries]};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"AttachmentsNotDownloaded" substitutionVariables: vars];
    
    NSError *error;
    NSArray *unfinishedAttachments = [self.delegate.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (unfinishedAttachments == nil)
    {
        NSLog(@"Fetch request 'AttachmentsNotDownloaded' failed: %@", error);
        abort();
    }
    if (TRANSFER_DEBUG) NSLog(@"flushPendingAttachmentDownloads found %d unfinished downloads", [unfinishedAttachments count]);
    NSMutableArray * pendingAttachments = [[NSMutableArray alloc]init];
    for (Attachment * attachment in unfinishedAttachments) {
        AttachmentState attachmentState = attachment.state;
        if (attachmentState == kAttachmentWantsTransfer ||
            attachmentState == kAttachmentDownloadIncomplete)
        {
            [pendingAttachments enqueue:attachment];
            [self enqueueDownloadOfAttachment:attachment];
        }
    }
    return pendingAttachments;
}

- (void) flushPendingAttachmentDownloads {
    NSArray * pendingAttachments = [self pendingAttachmentDownloads];
    for (Attachment * attachment in pendingAttachments) {
        [self enqueueDownloadOfAttachment:attachment];
    }
}

- (void) clearWaitingAttachmentTransfers {
    [_attachmentDownloadsWaiting removeAllObjects];
    [_attachmentUploadsWaiting removeAllObjects];
}

- (void)sortByTransferDate:(NSMutableArray*)attachmentArray {
    [attachmentArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        Attachment * a1 = (Attachment*)obj1;
        Attachment * a2 = (Attachment*)obj2;
        NSDate * d1 = [self transferDateFor:a1];
        NSDate * d2 = [self transferDateFor:a2];
        return [d1 compare:d2];
    }];
    if (TRANSFER_DEBUG) [self printTransferDatesFor:attachmentArray];
}

- (void)sortBySizeTodo:(NSMutableArray*)attachmentArray {
    [attachmentArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        Attachment * a1 = (Attachment*)obj1;
        Attachment * a2 = (Attachment*)obj2;
        NSNumber * sizeTodo1 = [NSNumber numberWithLongLong:[a1.cipheredSize longLongValue] - [a1.cipherTransferSize longLongValue]];
        NSNumber * sizeTodo2 = [NSNumber numberWithLongLong:[a2.cipheredSize longLongValue] - [a2.cipherTransferSize longLongValue]];
        return [sizeTodo1 compare:sizeTodo2];
    }];
    if (TRANSFER_DEBUG) [self printTransferSizesFor:attachmentArray];
}

- (void) printTransferDatesFor:(NSArray*)attachmentArray {
    for (Attachment * a in attachmentArray) {
        NSLog(@"transferDate %@ interval %f failed %@", [self transferDateFor:a],[self transferRetryIntervalFor:a],a.transferFailed);
    }
}

- (void) printTransferSizesFor:(NSArray*)attachmentArray {
    for (Attachment * a in attachmentArray) {
         NSNumber * todo = [NSNumber numberWithLongLong:[a.cipheredSize longLongValue]-[a.cipherTransferSize longLongValue]];
        NSLog(@"transferSize todo %@ size %@ transfered %@", todo, a.cipheredSize, a.cipherTransferSize);
    }
}

- (void)checkTransferQueues {
    if (TRANSFER_DEBUG) NSLog(@"checkTransferQueues");
    NSArray * da = [_attachmentDownloadsActive copy];
    for (Attachment * a in da) {
        if (a.state != kAttachmentTransfering && a.state != kAttachmentTransferScheduled) {
            NSLog(@"#WARNING: checkTransferQueues : attachment with bad state %@ in _attachmentDownloadsActive, dequeueing url = %@", [Attachment getStateName:a.state], a.remoteURL);
            [self dequeueDownloadOfAttachment:a];
        }
    }
    da = [_attachmentUploadsActive copy];
    for (Attachment * a in da) {
        if (a.state != kAttachmentTransfering && a.state != kAttachmentTransferScheduled) {
            NSLog(@"#WARNING: checkTransferQueues : attachment with bad state %@ in _attachmentUploadsActive, dequeueing url = %@", [Attachment getStateName:a.state], a.uploadURL);
            [self dequeueUploadOfAttachment:a];
        }
    }
    NSArray * pendingDownloads = [self pendingAttachmentDownloads];
    for (Attachment * a in pendingDownloads) {
        if ([_attachmentDownloadsWaiting indexOfObject:a] == NSNotFound && [_attachmentDownloadsActive indexOfObject:a] == NSNotFound) {
            NSLog(@"#WARNING: checkTransferQueues : attachment with state %@ not in transfer queues, enqueuing download, url = %@", [Attachment getStateName:a.state], a.remoteURL);
            [self enqueueDownloadOfAttachment:a];
        }
    }
    
    NSArray * pendingUploads = [self pendingAttachmentUploads];
    for (Attachment * a in pendingUploads) {
        if ([_attachmentUploadsWaiting indexOfObject:a] == NSNotFound && [_attachmentUploadsActive indexOfObject:a] == NSNotFound) {
            NSLog(@"#WARNING: checkTransferQueues : attachment with state %@ not in transfer queues, enqueuing upload, url = %@", [Attachment getStateName:a.state], a.uploadURL);
            [self enqueueUploadOfAttachment:a];
        }
    }
    if (TRANSFER_DEBUG) NSLog(@"checkTransferQueues ready");
}

- (void) enqueueDownloadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment %@", theAttachment.remoteURL);
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment before active=%d, waiting=%d",_attachmentDownloadsActive.count,_attachmentDownloadsWaiting.count);
    if (_attachmentDownloadsActive.count >= kMaxConcurrentDownloads) {
        if ([_attachmentDownloadsWaiting indexOfObject:theAttachment] == NSNotFound) {
            [_attachmentDownloadsWaiting enqueue:theAttachment];
        } else {
            if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment: already in waiting queue: %@", theAttachment.remoteURL);
        }
    } else {
        if ([_attachmentDownloadsActive indexOfObject:theAttachment] == NSNotFound) {
            [self scheduleNewDownloadFor:theAttachment];
            [_attachmentDownloadsActive enqueue:theAttachment];
        } else {
            if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment: already in active queue: %@", theAttachment.remoteURL);
        }
    }
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment after active=%d, waiting=%d",_attachmentDownloadsActive.count,_attachmentDownloadsWaiting.count);
    [self updateNetworkActivityIndicator];
}

- (void) enqueueUploadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment %@", theAttachment.uploadURL);
    if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment before active=%d, waiting=%d",_attachmentUploadsActive.count,_attachmentUploadsWaiting.count);
    if (_attachmentUploadsActive.count >= kMaxConcurrentUploads) {
        if ([_attachmentUploadsWaiting indexOfObject:theAttachment] == NSNotFound) {
            [_attachmentUploadsWaiting enqueue:theAttachment];
        } else {
            if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment: already in waiting queue: %@", theAttachment.uploadURL);            
        }
    } else {
        if ([_attachmentUploadsActive indexOfObject:theAttachment] == NSNotFound) {
            [self scheduleNewUploadFor:theAttachment];
            [_attachmentUploadsActive enqueue:theAttachment];
        } else {
            if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment: already in active queue: %@", theAttachment.uploadURL);
        }
    }
    if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment after active=%d, waiting=%d",_attachmentUploadsActive.count,_attachmentUploadsWaiting.count);
    [self updateNetworkActivityIndicator];
}

- (void) updateNetworkActivityIndicator {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(_attachmentUploadsActive.count > 0 || _attachmentDownloadsActive.count > 0)];
}

- (void) dequeueDownloadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment %@", theAttachment.remoteURL);
    if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment before active=%d, waiting=%d",_attachmentDownloadsActive.count,_attachmentDownloadsWaiting.count);
    NSUInteger index = [_attachmentDownloadsActive indexOfObject:theAttachment];
    if (index != NSNotFound) {
        [_attachmentDownloadsActive removeObjectAtIndex:index];
        if (_attachmentDownloadsWaiting.count > 0) {
            [self sortByTransferDate:_attachmentDownloadsWaiting];
            [self enqueueDownloadOfAttachment:[_attachmentDownloadsWaiting dequeue]];
        }
        if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment (a) after active=%d, waiting=%d",_attachmentDownloadsActive.count,_attachmentDownloadsWaiting.count);
    } else {
        // in case it is in the waiting queue remove it from there
        [_attachmentDownloadsWaiting removeObject:theAttachment];
        if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment (b) after active=%d, waiting=%d",_attachmentDownloadsActive.count,_attachmentDownloadsWaiting.count);
    }
    [self updateNetworkActivityIndicator];
}

- (void) dequeueUploadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment %@", theAttachment.uploadURL);
    if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment before active=%d, waiting=%d",_attachmentUploadsActive.count,_attachmentUploadsWaiting.count);
    NSUInteger index = [_attachmentUploadsActive indexOfObject:theAttachment];
    if (index != NSNotFound) {
        [_attachmentUploadsActive removeObjectAtIndex:index];
        if (_attachmentUploadsWaiting.count > 0) {
            [self sortBySizeTodo:_attachmentUploadsWaiting];
            [self enqueueUploadOfAttachment:[_attachmentUploadsWaiting dequeue]];
        }
        if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment (a) after active=%d, waiting=%d",_attachmentUploadsActive.count,_attachmentUploadsWaiting.count);
    } else {
        // in case it is in the waiting queue remove it from there
        [_attachmentUploadsWaiting removeObject:theAttachment];
    }
    if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment (b) after active=%d, waiting=%d",_attachmentUploadsActive.count,_attachmentUploadsWaiting.count);
    [self updateNetworkActivityIndicator];
}

- (void) downloadFinished:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"downloadFinished of %@", theAttachment.remoteURL);
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self dequeueDownloadOfAttachment:theAttachment];
    [SoundEffectPlayer messageArrived];
}

- (void) uploadFinished:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"uploadFinished of %@", theAttachment.uploadURL);
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self dequeueUploadOfAttachment:theAttachment];
}

- (void) downloadFailed:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"downloadFailed of %@", theAttachment.remoteURL);
    theAttachment.transferFailures = theAttachment.transferFailures + 1;
    theAttachment.transferFailed = [[NSDate alloc] init];
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self dequeueDownloadOfAttachment:theAttachment];
    [self enqueueDownloadOfAttachment:theAttachment];
    //[self scheduleNewDownloadFor:theAttachment];
}

- (void) uploadFailed:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"uploadFailed of %@", theAttachment.uploadURL);
    theAttachment.transferFailures = theAttachment.transferFailures + 1;
    theAttachment.transferFailed = [[NSDate alloc] init];
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self dequeueUploadOfAttachment:theAttachment];
    [self enqueueUploadOfAttachment:theAttachment];
    // [self scheduleNewUploadFor:theAttachment];
}

- (double) transferRetryIntervalFor:(Attachment *)theAttachment {
    if (theAttachment.transferFailures == 0) {
        return 0.0;
    }
    // double factor = (double)arc4random()/(double)0xffffffff;
    double factor = 1;
    double retryTime = (2.0 + factor) * (theAttachment.transferFailures * theAttachment.transferFailures + 1);
    //double retryTime = 2.0;
    return retryTime;
}

- (NSDate*) transferDateFor:(Attachment *)theAttachment {
    if (theAttachment.transferFailed != nil) {
        return [NSDate dateWithTimeInterval:[self transferRetryIntervalFor:theAttachment] sinceDate:theAttachment.transferFailed];
    } else {
        return [NSDate dateWithTimeIntervalSinceNow:0];
    }
}

-(void) scheduleNewTransferFor:(Attachment *)theAttachment inSecs:(double)retryTime withSelector:(SEL)theTransferSelector withErrorKey: (NSString*) errorKey {
    if (theAttachment.transferRetryTimer != nil) {
        if (TRANSFER_DEBUG) NSLog(@"scheduleNewTransferFor:%@ invalidating timer for transfer in %f secs", theAttachment.remoteURL, [[theAttachment.transferRetryTimer fireDate] timeIntervalSinceNow]);
        [theAttachment.transferRetryTimer invalidate];
        theAttachment.transferRetryTimer = nil;
    }
    if (![self.delegate.internetReachabilty isReachable]) {
        // do not schedule retrys without internet connection
        if (TRANSFER_DEBUG) NSLog(@"No Internet, not scheduling: scheduleNewTransferFor:%@ failures = %i, retry in = %f secs",[theAttachment.message.isOutgoing isEqual:@(YES)]?theAttachment.uploadURL: theAttachment.remoteURL, theAttachment.transferFailures, retryTime);
        return;
    }
    if (theAttachment.state == kAttachmentUploadIncomplete ||
        theAttachment.state == kAttachmentDownloadIncomplete ||
        theAttachment.state == kAttachmentWantsTransfer) {
        if (TRANSFER_DEBUG) NSLog(@"scheduleNewTransferFor:%@ failures = %i, retry in = %f secs",[theAttachment.message.isOutgoing isEqual:@(YES)]?theAttachment.uploadURL: theAttachment.remoteURL, theAttachment.transferFailures, retryTime);
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
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
        if (TRANSFER_DEBUG) NSLog(@"scheduleTransferRetryFor:%@ max retry count reached, failures = %i, no transfer scheduled",
              [theAttachment.message.isOutgoing isEqual:@(YES)]?theAttachment.uploadURL: theAttachment.remoteURL, theAttachment.transferFailures);
    }
}


-(void) scheduleNewDownloadFor:(Attachment *)theAttachment {
    [self scheduleNewTransferFor:theAttachment
                          inSecs:[[self transferDateFor:theAttachment] timeIntervalSinceNow]
                    withSelector:@selector(downloadOnTimer:)
                    withErrorKey:@"attachment_download_failed"];
}

-(void) scheduleNewUploadFor:(Attachment *)theAttachment {
    [self scheduleNewTransferFor:theAttachment
                          inSecs:[[self transferDateFor:theAttachment] timeIntervalSinceNow]
                    withSelector:@selector(uploadOnTimer:)
                    withErrorKey:@"attachment_upload_failed"];
}

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

- (void) bing: (GenericResultHandler) handler {
    [_serverConnection invoke: @"bing" withParams: nil onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(YES);
        } else {
            NSLog(@"bing failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

- (void) ready: (GenericResultHandler) handler {
    [_serverConnection invoke: @"ready" withParams: nil onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(YES);
        } else {
            NSLog(@"ready failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

- (void) getTime: (DateHandler) handler {
    [_serverConnection invoke: @"getTime" withParams: nil onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSDate * date = [HXOBackend dateFromMillis:responseOrError];
            handler(date);
        } else {
            NSLog(@"getTime failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) syncTime {
    [self getTime:^(NSDate *date) {
        if (date != nil) {
            [self saveServerTime:date];
        }
    }];
}

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
            handler(responseOrError, nil);
        } else {
            NSLog(@"SRP Phase 1 failed: %@", responseOrError);
            handler(nil, responseOrError);
        }
    }];
}

- (void) srpPhase2: (NSString*) M handler: (SrpHanlder) handler {
    [_serverConnection invoke: @"srpPhase2" withParams: @[M] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(responseOrError, nil);
        } else {
            NSLog(@"SRP Phase 2 failed: %@", responseOrError);
            handler(nil, responseOrError);
        }
    }];
}

- (void) hello:(NSNumber*) clientTime  crashFlag:(BOOL)hasCrashed updateFlag:(BOOL)hasUpdated unclean:(BOOL)uncleanShutdown handler:(HelloHandler) handler {
    // NSLog(@"hello: %@", clientTime);
#ifdef FULL_HELLO
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machineName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    NSString * supportTag = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOSupportTag];
    if (supportTag != nil) {
        if ( ! [supportTag isEqualToString: @""]) {
            NSLog(@"Using support tag '%@'", supportTag);
        }
    }else {
        supportTag = @"";
    }
    NSDictionary * initParams = @{
                             @"clientTime"     : clientTime,
                             @"systemLanguage" : [[NSLocale preferredLanguages] objectAtIndex:0],
                             @"deviceModel"    : machineName,
                             @"systemName"     : [UIDevice currentDevice].systemName,
                             @"systemVersion"  : [UIDevice currentDevice].systemVersion,
                             @"clientName"     : [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                             @"clientVersion"  : [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                             @"clientBuildNumber"  : [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                             @"clientLanguage" : NSLocalizedString(@"language_code", nil),
                             @"supportTag"     : supportTag
                             };
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:initParams];
    if (hasCrashed) {
        params[@"clientCrashed"] = @(hasCrashed);
    }
    if (hasUpdated) {
        params[@"clientUpdated"] = @(hasUpdated);
    }
    if (uncleanShutdown) {
        params[@"connectionUncleanShutdown"] = @(uncleanShutdown);
    }
#else
    NSDictionary *params = @{ @"clientTime" : clientTime};
#endif
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
    [self hello:clientTime
      crashFlag:self.firstConnectionAfterCrashOrUpdate && _delegate.launchedAfterCrash
     updateFlag:self.firstConnectionAfterCrashOrUpdate && _delegate.runningNewBuild
        unclean: _uncleanConnectionShutdown
        handler:^(NSDictionary * result)
    {
        if (result != nil) {
            self.serverInfo = result;
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
    if ([objectToValidate isKindOfClass:[NSNull class]]) {
        NSLog(@"ERROR: validateObject: object for entity %@ is null", entityName);
        return NO;
    }
    BOOL myResult = [self validateObject:objectToValidate forEntity:entityName error:&myError];
    if (!myResult) {
        NSLog(@"ERROR: %@", myError);
    }
    return myResult;
}

NSArray * objectIds(NSArray* managedObjects) {
    NSMutableArray * result = [NSMutableArray new];
    for (NSManagedObject * obj in managedObjects) {
        [result addObject:obj.objectID];
    }
    return result;
}

NSArray * managedObjects(NSArray* objectIds, NSManagedObjectContext * context) {
    NSMutableArray * result = [NSMutableArray new];
    for (NSManagedObjectID * objId in objectIds) {
        [result addObject:[context objectWithID:objId]];
    }
    return result;
}

// client calls this method to send a Talkmessage along with the intended recipients in the deliveries array
// the return result contains an array with updated deliveries
- (void) deliveryRequest: (HXOMessage*) message withDeliveries: (NSArray*) deliveries {
    NSMutableDictionary * messageDict = [message rpcDictionary];
    NSMutableArray * deliveryDicts = [[NSMutableArray alloc] init];
    for (Delivery * delivery in deliveries) {
        NSMutableDictionary * myDict = [delivery rpcDictionary];
        if (delivery.receiver != nil) {
            myDict[@"receiverId"] = delivery.receiver.clientId;
        }
        if (delivery.group != nil) {
            myDict[@"groupId"] = delivery.group.clientId;
        }
        [deliveryDicts addObject: myDict];
    }
    // validate
    if (USE_VALIDATOR) {
        for (NSDictionary * d in deliveryDicts) {
            [self validateObject: d forEntity:@"RPC_TalkDelivery_out"];  // TODO: Handle Validation Error
        }
    }
    
    if (USE_VALIDATOR) [self validateObject: messageDict forEntity:@"RPC_TalkMessage_out"]; // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"deliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSArray * deliveryIds = objectIds(deliveries);
            [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
                NSArray * deliveries = managedObjects(deliveryIds,context);
                // NSLog(@"deliveryRequest() returned deliveries: %@", responseOrError);
                NSArray * updatedDeliveryDicts = (NSArray*)responseOrError;
                int i = 0;
                for (Delivery * delivery in deliveries) {
                    if (USE_VALIDATOR) [self validateObject: updatedDeliveryDicts[i] forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
                    if (DELIVERY_TRACE) {NSLog(@"deliveryRequest result: Delivery state '%@'->'%@' for messageTag %@ id %@",delivery.state, updatedDeliveryDicts[i][@"state"], updatedDeliveryDicts[i][@"messageTag"],updatedDeliveryDicts[i][@"messageId"] );}
                    [delivery updateWithDictionary: updatedDeliveryDicts[i++]];
                    if (delivery.receiver != nil) {
                        delivery.receiver.latestMessageTime = message.timeAccepted;
                    }
                    if (delivery.group != nil) {
                        delivery.group.latestMessageTime = message.timeAccepted;
                    }
                    if (DELIVERY_TRACE) {NSLog(@"Delivery message time update: messageId = %@, message.timeAccepted=%@, delivery.receiver.latestMessageTime=%@, delivery.group.latestMessageTime=%@",message.messageId, message.timeAccepted, delivery.receiver.latestMessageTime, delivery.group.latestMessageTime);}
                }
                
                for (Delivery * delivery in deliveries) {
                    if (delivery.receiver != nil) {
                        [context performBlock:^{
                            NSManagedObjectID * contactId = delivery.receiver.objectID;
                            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                                [context refreshObject: [context objectWithID:contactId] mergeChanges: YES];
                            }];
                        }];
                    }
                    if (delivery.group != nil) {
                        [context performBlock:^{
                            NSManagedObjectID * contactId = delivery.group.objectID;
                            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                                [context refreshObject: [context objectWithID:contactId] mergeChanges: YES];
                            }];
                        }];
                    }
                }
                
            }];
        } else {
            NSLog(@"deliveryRequest failed: %@", responseOrError);
        }
    }];
}

- (void) deliveryConfirm: (NSString*) messageId withDelivery: (Delivery*) delivery {
    // NSLog(@"deliveryConfirm: %@", delivery);
    [_serverConnection invoke: @"deliveryConfirm" withParams: @[messageId] onResponse: ^(id responseOrError, BOOL success) {
        if (success && responseOrError != nil && [responseOrError isKindOfClass:[NSDictionary class]]) {
            // NSLog(@"deliveryConfirm() returned deliveries: %@", responseOrError);
            if (USE_VALIDATOR) [self validateObject: responseOrError forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
            if (DELIVERY_TRACE) {NSLog(@"deliveryConfirm result: state %@->%@ for messageTag %@",delivery.state, responseOrError[@"state"], delivery.message.messageTag);}
            if ([delivery.state isEqualToString: responseOrError[@"state"]]) {
                if (GLITCH_TRACE) {NSLog(@"#GLITCH: deliveryConfirm result: state unchanged %@->%@ for messageTag %@",delivery.state, responseOrError[@"state"], delivery.message.messageTag);}
            }
            [delivery updateWithDictionary: responseOrError];
            [self.delegate saveDatabase];
        } else {
            NSLog(@"#ERROR: deliveryConfirm() failed, response: %@", responseOrError);
        }
    }];
}

- (void) deliveryAcknowledge: (Delivery*) delivery {
    if (DELIVERY_TRACE) {NSLog(@"deliveryAcknowledge: %@", delivery);}
        
    [_serverConnection invoke: @"deliveryAcknowledge" withParams: @[delivery.message.messageId, delivery.receiver.clientId]
                   onResponse: ^(id responseOrError, BOOL success)
    {
        if (success && responseOrError != nil && [responseOrError isKindOfClass:[NSDictionary class]]) {
            // NSLog(@"deliveryAcknowledge() returned delivery: %@", responseOrError);
            if (USE_VALIDATOR) [self validateObject: responseOrError forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
            
            if (![responseOrError isKindOfClass:[NSDictionary class]]) {
                NSLog(@"ERROR: deliveryAcknowledge response is null");
                return;
            }
            
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
            [self.delegate.mainObjectContext refreshObject: delivery.message mergeChanges: YES];
        } else {
            NSLog(@"#ERROR:deliveryAcknowledge() failed, response: %@", responseOrError);
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

- (void) updatePresence: (NSString*) clientName
             withStatus: (NSString*) clientStatus
             withAvatar: (NSString*)avatarURL
                withKey: (NSData*) keyId
   withConnectionStatus: (NSString*) clientConnectionStatus
                handler:(GenericResultHandler)handler
{
    NSDictionary *params = @{
                             @"clientName" : clientName,
                             @"clientStatus" : clientStatus,
                             @"avatarUrl" : avatarURL,
                             @"keyId" : [keyId hexadecimalString],
                             @"connectionStatus": clientConnectionStatus
                             };
    if (USE_VALIDATOR) [self validateObject: params forEntity:@"RPC_TalkPresence_out"];  // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"updatePresence" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"updatePresence() got result: %@", responseOrError);
            handler(YES);
        } else {
            NSLog(@"updatePresence() failed: %@", responseOrError);
            handler(NO);
        }
    }];
}

- (void) updatePresenceWithHandler:(GenericResultHandler)handler {
    NSString * myAvatarURL = [UserProfile sharedProfile].avatarURL;
    if (myAvatarURL == nil) {
        myAvatarURL = @"";
    }
    UserProfile * myProfile = [UserProfile sharedProfile];
    NSString * myNickName = myProfile.nickName;
    NSString * myClientStatus = [UserProfile sharedProfile].status;
    if (myClientStatus == nil) {
        myClientStatus = @"";
    }
    if (myNickName == nil) {
        myNickName = @"";
    }
    NSString * myConnectionStatus = [UserProfile sharedProfile].connectionStatus;
    if (myConnectionStatus == nil) {
        myConnectionStatus = @"online";
    }
    [self updatePresence: myNickName
              withStatus: myClientStatus
              withAvatar: myAvatarURL
                 withKey: myProfile.publicKeyIdData
    withConnectionStatus:myConnectionStatus
                 handler: handler];
}

- (void) modifyPresence:(NSDictionary *)params handler:(GenericResultHandler)handler{
    // NSLog(@"modifyPresence: %@, %@, %@", clientName, clientStatus, avatarURL);
    //if (USE_VALIDATOR) [self validateObject: params forEntity:@"RPC_TalkPresence_out"];  // TODO: Handle Validation Error
    
    [_serverConnection invoke: @"modifyPresence" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"modifyPresence() got result: %@", responseOrError);
            if (handler) handler(YES);
        } else {
            NSLog(@"modifyPresence() failed: %@", responseOrError);
            if (handler) handler(NO);
        }
    }];
}

- (void) modifyPresenceClientName: (NSString*) clientName handler:(GenericResultHandler)handler {
    [self modifyPresence:@{@"clientName" : clientName} handler:handler];
}

- (void) modifyPresenceClientStatus: (NSString*) clientStatus handler:(GenericResultHandler)handler {
    [self modifyPresence:@{@"clientStatus" : clientStatus} handler:handler];
}

- (void) modifyPresenceAvatarURL: (NSString*) avatarURL handler:(GenericResultHandler)handler {
    [self modifyPresence:@{@"avatarUrl" : avatarURL} handler:handler];
}

- (void) modifyPresenceKeyId: (NSData*) keyId handler:(GenericResultHandler)handler {
    [self modifyPresence:@{@"keyId" : [keyId hexadecimalString]} handler:handler];
}

- (void) modifyPresenceConnectionStatus: (NSString*) connectionStatus handler:(GenericResultHandler)handler {
    [self modifyPresence:@{@"connectionStatus" : connectionStatus} handler:handler];
}

// Call one of the following five function after one of the presence fields has been updated

- (void) modifyPresenceClientNameWithHandler:(GenericResultHandler)handler {
    [self modifyPresenceClientName:[UserProfile sharedProfile].nickName handler:handler];
}

- (void) modifyPresenceClientStatusWithHandler:(GenericResultHandler)handler {
    NSString * myClientStatus = [UserProfile sharedProfile].status;
    if (myClientStatus == nil) {
        myClientStatus = @"";
    }
    [self modifyPresenceClientStatus:myClientStatus handler:handler];
}

- (void) modifyPresenceAvatarURLWithHandler:(GenericResultHandler)handler {
    NSString * myAvatarURL = [UserProfile sharedProfile].avatarURL;
    if (myAvatarURL == nil) {
        myAvatarURL = @"";
    }
    [self modifyPresenceAvatarURL:myAvatarURL handler:handler];
}

- (void) modifyPresenceKeyIdWithHandler:(GenericResultHandler)handler {
    [self modifyPresenceKeyId:[UserProfile sharedProfile].publicKeyIdData handler:handler];
}

- (void) modifyPresenceConnectionStatusWithHandler:(GenericResultHandler)handler {
    NSString * myConnectionStatus = [UserProfile sharedProfile].connectionStatus;
    if (myConnectionStatus == nil) {
        myConnectionStatus = @"online";
    }
    [self modifyPresenceConnectionStatus:myConnectionStatus handler:handler];
}

- (void) changePresenceToNotTyping {
    if (![@"online" isEqualToString:[UserProfile sharedProfile].connectionStatus]) {
        [UserProfile sharedProfile].connectionStatus=@"online";
        [self modifyPresenceConnectionStatusWithHandler:nil];
    }
}

- (void) changePresenceToTyping {
    if (![@"typing" isEqualToString:[UserProfile sharedProfile].connectionStatus]) {
        [UserProfile sharedProfile].connectionStatus=@"typing";
        [self modifyPresenceConnectionStatusWithHandler:nil];
    }
}
/*
 if (fullPresenceUpdate) {
 [self updatePresenceWithHandler:^(BOOL success) {
 NSLog(@"Avatar upload succeeded=%d",success);
 }];
 } else {
 [self modifyPresenceAvatarURLWithHandler:^(BOOL success) {
 NSLog(@"Avatar upload succeeded=%d",success);
 }];
 }
 */

- (void) profileUpdatedByUser:(NSNotification*)aNotification {
    if (_state == kBackendReady) {
        NSDictionary * itemsChanged = aNotification.userInfo[@"itemsChanged"];
        //NSLog(@"notification = %@, itemsChanged=%@", aNotification,itemsChanged);
        BOOL publicKeyChanged = itemsChanged == nil || [itemsChanged[@"publicKey"] boolValue];
        BOOL avatarChanged = itemsChanged == nil || [itemsChanged[@"avatar"] boolValue];
        BOOL nickNameChanged = itemsChanged == nil || [itemsChanged[@"nickName"] boolValue];
        BOOL userStatusChanged = itemsChanged == nil || [itemsChanged[@"userStatus"] boolValue];
        
        if (nickNameChanged) {
            [self modifyPresenceClientNameWithHandler:^(BOOL success) { }];
        }
        if (userStatusChanged) {
            [self modifyPresenceClientStatusWithHandler:^(BOOL success) { }];
        }
        if (avatarChanged) {
            [self uploadAvatarIfNeededWithCompletion:^(BOOL ok) {
                if (ok || UserProfile.sharedProfile.avatar == nil) {
                    [self modifyPresenceAvatarURLWithHandler:^(BOOL success) {
                        NSLog(@"Avatar upload and presence update succeeded=%d",success);
                    }];
                }
            }];
        }
        if (publicKeyChanged) {
            [self updateKeyWithHandler:^(BOOL ok) {
                if (ok) {
                    //[self updatePresenceWithHandler:^(BOOL ok) {
                    [self modifyPresenceKeyIdWithHandler:^(BOOL ok) {
                        if (ok) {
                            //[self updateGroupKeysForMyGroupMemberships];
                        }
                    }];
                }
            }];
        }
    }
}

+ (NSData *) calcKeyId:(NSData *) myKeyBits {
    return [CCRSA calcKeyId:myKeyBits];
}

+ (NSString *) keyIdString:(NSData *) myKeyId {
    return [CCRSA keyIdString:myKeyId];
}

- (void) updateKey: (NSData*) publicKey handler:(GenericResultHandler) handler {
    // NSLog(@"updateKey: %@", publicKey);
    NSData * myKeyId = [HXOBackend calcKeyId:publicKey];
    NSDictionary *params = @{
                             @"key" :   [publicKey asBase64EncodedString], 
                             @"keyId" : [myKeyId hexadecimalString]
                             };
    if (USE_VALIDATOR) [self validateObject: params forEntity:@"RPC_TalkKey_out"];  // TODO: Handle Validation Error

    [_serverConnection invoke: @"updateKey" withParams: @[params] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"updateKey() got result: %@", responseOrError);
            handler(YES);
        } else {
            handler(NO);
            NSLog(@"updateKey() failed: %@", responseOrError);
        }
    }];
}

- (void) updateKeyWithHandler:(GenericResultHandler) handler {
    NSData * myKeyBits = [[UserProfile sharedProfile] publicKey];
    [self updateKey:myKeyBits handler:handler];
}

- (void) verifyKey: (NSData*) publicKey handler:(BoolResultHandler) handler {
    // NSLog(@"verifyKey: %@", publicKey);
    NSData * myKeyId = [HXOBackend calcKeyId:publicKey];
    NSString * myKeyIdString = [myKeyId hexadecimalString];
    
    [_serverConnection invoke: @"verifyKey" withParams: @[myKeyIdString] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"verifyKey() got result: %@", responseOrError);
            handler([responseOrError boolValue], YES);
        } else {
            NSLog(@"verifyKey() failed: %@", responseOrError);
            handler(NO,NO);
        }
    }];
}

- (void) verifyKeyWithHandler:(BoolResultHandler) handler {
    NSData * myKeyBits = [[UserProfile sharedProfile] publicKey];
    [self verifyKey:myKeyBits handler:handler];
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
/*
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
*/
- (void) generatePairingToken: (NSUInteger) maxUseCount validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler {
    // NSLog(@"generatePairingToken:");
    [_serverConnection invoke: @"generatePairingToken" withParams: @[@(maxUseCount), @(seconds)] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"generatePairingToken(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"generatePairingToken(): failed: %@", responseOrError);
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
            [self updatePresenceWithHandler:^(BOOL ok) {
            }];
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
            handler(nil);
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

- (void) getKeyForClientId: (NSString*)forClientId withKeyId:(NSString*) keyId keyHandler:(PublicKeyHandler) handler {
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
    if (CONNECTION_TRACE) { NSLog(@"createFileForStorageWithSize:");}
    
    [_serverConnection invoke: @"createFileForStorage" withParams: @[size] onResponse: ^(id responseOrError, BOOL success) {
        if (success && [responseOrError isKindOfClass: [NSDictionary class]]) {
            if (CONNECTION_TRACE) { NSLog(@"createFileForStorageWithSize(): got result: %@", responseOrError);}
            handler(responseOrError);
        } else {
            NSLog(@"createFileForStorageWithSize(): failed - response: %@", responseOrError);
            handler(nil);
        }
    }];
}

//FileHandles createFileForTransfer(int contentLength);
- (void) createFileForTransferWithSize:(NSNumber*) size completionHandler:(FileURLRequestHandler) handler {
    if (CONNECTION_TRACE) { NSLog(@"createFileForStorageWithSize:");}
    
    [_serverConnection invoke: @"createFileForTransfer" withParams: @[size] onResponse: ^(id responseOrError, BOOL success) {
        if (success && [responseOrError isKindOfClass: [NSDictionary class]]) {
            if (CONNECTION_TRACE) { NSLog(@"createFileForTransferWithSize(): got result: %@", responseOrError);}
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

- (void) inviteFriend: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"inviteFriend");
    [_serverConnection invoke: @"inviteFriend" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}

- (void) disinviteFriend: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"disinviteFriend");
    [_serverConnection invoke: @"disinviteFriend" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}

- (void) acceptFriend: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"acceptFriend");
    [_serverConnection invoke: @"acceptFriend" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}

- (void) refuseFriend: (NSString*) clientId handler: (GenericResultHandler) handler {
    //NSLog(@"refuseFriend");
    [_serverConnection invoke: @"refuseFriend" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}


#pragma mark - Incoming RPC Calls

- (void) incomingDelivery: (NSArray*) params {
    [[AppDelegate instance] performInNewBackgroundContext:^(NSManagedObjectContext *context) {
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
        
        if (USE_VALIDATOR) [self validateObject: messageDict forEntity:@"RPC_TalkMessage_in"];  // TODO: Handle Validation Error
        if (USE_VALIDATOR) [self validateObject: deliveryDict forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
        
        [self receiveMessage: messageDict withDelivery: deliveryDict inContext:context];

    }];
}

// utility function to avoid code duplication
-(Delivery *) getDeliveryByMessageTagAndReceiverId:(NSString *) theMessageTag withReceiver: (NSString *) theReceiverId inContext:(NSManagedObjectContext*)context {
    NSDictionary * vars = @{ @"messageTag" : theMessageTag,
                             @"receiverId" : theReceiverId};
    if (DELIVERY_TRACE) NSLog(@"getDeliveryByMessageTagAndReceiverId vars = %@", vars);
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"DeliveryByMessageTagAndReceiverId" substitutionVariables: vars];
    NSError *error;
    NSArray *deliveries = [context executeFetchRequest:fetchRequest error:&error];
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
        if (DELIVERY_TRACE) NSLog(@"Delivery with MessageTag %@ for receiver %@ not in deliveries", theMessageTag, theReceiverId);
    }
    return delivery;
}

// utility function to avoid code duplication
-(Delivery *) getDeliveryByMessageTagAndGroupId:(NSString *) theMessageTag withGroupId: (NSString *) theGroupId inContext:(NSManagedObjectContext*)context {
    NSDictionary * vars = @{ @"messageTag" : theMessageTag,
                             @"groupId" : theGroupId};
    NSLog(@"getDeliveryByMessageTagAndGroupId vars = %@", vars);
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"DeliveryByMessageTagAndGroupId" substitutionVariables: vars];
    NSError *error;
    NSArray *deliveries = [context executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"getDeliveryByMessageTagAndGroupId: Fetch request failed: %@", error);
        abort();
    }
    Delivery * delivery = nil;
    if (deliveries.count > 0) {
        delivery = deliveries[0];
        if (deliveries.count > 1) {
            NSLog(@"WARNING: Multiple deliveries with MessageTag %@ for group %@ found", theMessageTag, theGroupId);
        }
    } else {
        if (DELIVERY_TRACE) NSLog(@"Delivery with MessageTag %@ for group %@ not in deliveries", theMessageTag, theGroupId);
    }
    return delivery;
}
// utility function to avoid code duplication
-(Delivery *) getDeliveryByMessageTagAndGroupIdAndReceiverId:(NSString *) theMessageTag withGroupId: (NSString *) theGroupId  withReceiverId:(NSString*) receiverId inContext:(NSManagedObjectContext*)context{
    NSDictionary * vars = @{ @"messageTag" : theMessageTag,
                             @"groupId" : theGroupId,
                             @"receiverId" : receiverId};
    NSLog(@"getDeliveryByMessageTagAndGroupIdAndReceiverId vars = %@", vars);
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"DeliveryByMessageTagAndGroupIdAndReceiverId" substitutionVariables: vars];
    NSError *error;
    NSArray *deliveries = [context executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"getDeliveryByMessageTagAndGroupId: Fetch request failed: %@", error);
        abort();
    }
    Delivery * delivery = nil;
    if (deliveries.count > 0) {
        delivery = deliveries[0];
        if (deliveries.count > 1) {
            NSLog(@"WARNING: Multiple deliveries with MessageTag %@ for group %@ found", theMessageTag, theGroupId);
        }
    } else {
        if (DELIVERY_TRACE) NSLog(@"Delivery with MessageTag %@ for group %@ not in deliveries", theMessageTag, theGroupId);
    }
    return delivery;
}


// called by server to notify us about status changes of outgoing deliveries we made
- (void) outgoingDelivery: (NSArray*) params {
    [self.delegate performInNewBackgroundContext:^(NSManagedObjectContext *context) {
        if (params.count != 1) {
            NSLog(@"outgoingDelivery: requires an array of one parameters (delivery), but got %d parameters.", params.count);
            return;
        }
        if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
            NSLog(@"outgoingDelivery: argument is not a valid object");
            return;
        }
        NSDictionary * deliveryDict = params[0];
        //NSLog(@"outgoingDelivery() called, dict = %@", deliveryDict);
        
        if (USE_VALIDATOR) [self validateObject: deliveryDict forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
        
        NSString * myMessageTag = deliveryDict[@"messageTag"];
        NSString * myMessageId = deliveryDict[@"messageId"];
        NSString * myReceiverId = deliveryDict[@"receiverId"];
        NSString * myGroupId = deliveryDict[@"groupId"];
        
        Delivery * myDelivery = nil;
        if (myGroupId) {
            if (myReceiverId != nil && myReceiverId.length > 0) {
                NSLog(@"myDelivery=%@",myDelivery);
                myDelivery = [self getDeliveryByMessageTagAndGroupIdAndReceiverId:myMessageTag withGroupId: myGroupId withReceiverId:myReceiverId inContext:context];
            } else {
                myDelivery = [self getDeliveryByMessageTagAndGroupId:myMessageTag withGroupId: myGroupId inContext:context];
            }
        } else {
            myDelivery = [self getDeliveryByMessageTagAndReceiverId:myMessageTag withReceiver: myReceiverId inContext:context];
        }
        if (DELIVERY_TRACE) NSLog(@"myDelivery: message Id: %@ receiver:%@ group:%@ objId:%@",myDelivery.message.messageId, myDelivery.receiver.clientId, myDelivery.group.clientId, myDelivery.objectID);
        
        HXOMessage * myMessage = [self getMessageById:myMessageId inContext:context];
        if (DELIVERY_TRACE) NSLog(@"myMessage: message Id: %@ tag:%@ sender:%@ deliveries:%@",myMessage.messageId, myMessage.messageTag, myMessage.senderId, myMessage.deliveries);
        
        if (myDelivery != nil) {
            // TODO: server should not send outgoingDelivery-changes for confirmed object, we just won't answer them for now to avoid ack-storms
            if ([myDelivery.state isEqualToString:@"confirmed"]) {
                // we have already acknowledged and received confirmation for ack, so server should have shut up and never sent us this in the first time
                if (myMessage != nil) {
                    NSLog(@"Bad server behavior: outgoingDelivery Notification received for already confirmed delivery msg-id: %@", deliveryDict[@"messageId"]);
                    [self.delegate saveContext:context];
                    NSManagedObjectID * deliveryObjId = myDelivery.objectID;
                    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                        Delivery * myDelivery = (Delivery*)[context objectWithID:deliveryObjId];
                        [self deliveryAcknowledge: myDelivery];
                    }];
                } else {
                    NSLog(@"#ERROR: outgoingDelivery delivery and message id mismatch, aborting message: %@", deliveryDict[@"messageId"]);
                    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                        [self deliveryAbort:myMessageId forClient:myReceiverId];
                    }];
                }
                return;
            }
            
            if (DELIVERY_TRACE) {NSLog(@"outgoingDelivery Notification: Delivery state '%@'->'%@' for messageTag %@ id %@",myDelivery.state, deliveryDict[@"state"], myMessageTag, deliveryDict[@"messageId"]);}
            
            if ([myDelivery.state isEqualToString:deliveryDict[@"state"]]) {
                if (GLITCH_TRACE) {NSLog(@"#GLITCH: Duplicate outgoingDelivery Notification: Delivery state for messageTag %@ id %@ was already %@, timeStamps: old %@ new %@", myMessageTag, deliveryDict[@"messageId"], myDelivery.state, myDelivery.timeChangedMillis, deliveryDict[@"timeChanged"]);}
            }
            [myDelivery updateWithDictionary: deliveryDict];
            
            [context performBlock:^{
                NSManagedObjectID * messageId = myDelivery.message.objectID;
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    [context refreshObject: [context objectWithID:messageId] mergeChanges: YES];
                }];
            }];
            
            // NSLog(@"Delivery state for messageTag %@ receiver %@ changed to %@", myMessageTag, myReceiverId, myDelivery.state);
            
            // TODO: decide what sound to play when a group message goes directly into state "confirmed"
            if ([myDelivery.state isEqualToString:@"delivered"] ) {
                [SoundEffectPlayer messageDelivered];
            } else {
                NSLog(@"#WARNING: We acknowledged Delivery state ‘%@‘ for messageTag %@ ", myDelivery.state, myMessageTag);
            }
            
            // TODO: check if acknowleding should be done when state set to delivered - right now we acknowledge every outgoingDelivery notification
            if (![myDelivery.state isEqualToString:@"confirmed"] ) {
                [self.delegate saveContext:self.delegate.currentObjectContext];
                NSManagedObjectID * deliveryObjId = myDelivery.objectID;
                [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                    Delivery * myDelivery = (Delivery*)[context objectWithID:deliveryObjId];
                    [self deliveryAcknowledge: myDelivery];
                }];
            }
            
        } else {
            // Can't remember delivery, probably database was nuked since, and we have not way to indicate succesful delivery to the user, so we just acknowledge
            [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
                if (myGroupId != nil) {
                    // just acknowledge group delivery so we don't get it all the time again
                    if (DELIVERY_TRACE) {NSLog(@"Acknowleding group delivery notification with messageTag %@ messageId %@ receiver %@ group %@", myMessageTag, deliveryDict[@"messageId"], myReceiverId, myGroupId);}
                    [_serverConnection invoke: @"deliveryAcknowledge" withParams: @[deliveryDict[@"messageId"], deliveryDict[@"receiverId"]]
                                   onResponse: ^(id responseOrError, BOOL success)
                     {
                         if (success) {
                             // ignore result because we do not keep track of individual group deliveries yet
                             if (DELIVERY_TRACE) {NSLog(@"deliveryAcknowledge() returned delivery: %@", responseOrError);}
                         } else {
                             NSLog(@"deliveryAcknowledge() for group delivery failed: %@", responseOrError);
                         }
                     }];
                } else if ([deliveryDict[@"senderId"] isEqualToString:[UserProfile sharedProfile].clientId]) {
                    NSLog(@"#WARNING: Acknowledging unknown outgoing delivery notification with messageTag %@ messageId %@ receiver %@ group %@ (Probably database had been nuked since sending)", myMessageTag, deliveryDict[@"messageId"], myReceiverId, myGroupId);
                    [_serverConnection invoke: @"deliveryAcknowledge" withParams: @[deliveryDict[@"messageId"], deliveryDict[@"receiverId"]]
                                   onResponse: ^(id responseOrError, BOOL success)
                     {
                         if (success) {
                             if (DELIVERY_TRACE) {NSLog(@"deliveryAcknowledge() returned delivery: %@", responseOrError);}
                         } else {
                             NSLog(@"deliveryAcknowledge() for delivery failed: %@", responseOrError);
                         }
                     }];
                }
            }];
        }
    }];
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
        // NSLog(@"presenceUpdatedNotification presence=%@",presence);
        [self presenceUpdated:presence];
    }
}

- (void) presenceModifiedNotification: (NSArray*) params {
    //TODO: Error checking
    for (id presence in params) {
        // NSLog(@"presenceModifiedNotification presence=%@",presence);
        [self presenceModified:presence];
    }
}

- (void) relationshipUpdated: (NSArray*) relationship {
    [self updateRelationship: relationship[0]];
}

- (id) ping {
    return [[NSNull alloc] init];
}

#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidOpen: (SRWebSocket*) webSocket {
    if (CONNECTION_TRACE) NSLog(@"webSocketDidOpen performRegistration: %d", _performRegistration);
    _certificateVerificationErrors = 0;
    if (_performRegistration) {
        [self setState: kBackendRegistering];
        [self performRegistration];
    } else {
        [self startAuthentication];
    }
}

- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    if (CONNECTION_TRACE) NSLog(@"webSocket didCloseWithCode %d reason: %@ clean: %d", code, reason, wasClean);
    _uncleanConnectionShutdown = code != 0 || [_serverConnection numberOfOpenRequests] !=0 || [_serverConnection numberOfFlushedRequests] != 0;
    if (CONNECTION_TRACE) NSLog(@"webSocket didCloseWithCode _uncleanConnectionShutdown = %d, openRequests = %d, flushedRequests = %d", _uncleanConnectionShutdown, [_serverConnection numberOfOpenRequests], [_serverConnection numberOfFlushedRequests]);
    BackendState oldState = _state;
    [self setState: kBackendStopped];
    if (oldState == kBackendStopping) {
        [self cancelStateNotificationDelayTimer];
        if ([self.delegate respondsToSelector:@selector(backendDidStop)]) {
            [self.delegate backendDidStop];
        }
    } else {
        [self reconnect];
    }
}

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@ %d", error, error.code);
    DoneBlock done = ^{
        [self setState: kBackendStopped]; // XXX do we need/want a failed state?
        [self reconnectWithBackoff];
    };
    if (error.code == 23556) { // constant found in source ... :(
        if (++_certificateVerificationErrors >= kHXOMaxCertificateVerificationErrors) {
            [self.delegate didFailWithInvalidCertificate: done];
            _certificateVerificationErrors = 0;
        } else {
            done();
        }
    } else {
        done();
    }
}

- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error {
    NSLog(@"didReceiveInvalidJsonRpcMessage: %@", error);
}


- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

#pragma mark - Group Avatar uploading

-(void)makeSureAvatarUploadedForGroup:(Group*)group withCallingContext:(NSManagedObjectContext*)callerContext withCompletion:(CompletionBlock)completion {
    [self.delegate saveContext:self.delegate.currentObjectContext];
    NSManagedObjectID * groupId = group.objectID;
    [self.delegate performInMainContext:^(NSManagedObjectContext *context) {
        Group * group = (Group *)[context objectWithID:groupId];
        if ([group iAmAdmin]) {
            NSData * myAvatarData = group.avatar;
            if (myAvatarData != nil && myAvatarData.length>0) {
                NSString * myCurrentAvatarURL = group.avatarURL;
                NSString * myCurrentAvatarUploadURL = group.avatarUploadURL;
                if (myCurrentAvatarURL != nil && myCurrentAvatarURL.length > 0) {
                    if (myCurrentAvatarUploadURL != nil && myCurrentAvatarUploadURL.length > 0) {
                        [self checkUploadStatus:myCurrentAvatarUploadURL hasSize:myAvatarData.length withCompletion:^(NSString *url, BOOL ok) {
                            if (!ok) {
                                group.avatarURL = @"";
                                [self uploadAvatarIfNeededForGroup:group withCompletion:^(NSError *theError) {
                                    NSLog(@"#ERROR: makeSureAvatarUploadedForGroup group %@ done, error=%@", group.nickName, theError);
                                    [callerContext performBlock:^{
                                        completion(theError);
                                    }];
                                }];
                                return;
                            }
                            [callerContext performBlock:^{
                                completion(nil);
                            }];
                        }];
                        return;
                    }
                }
            }
        }
        [callerContext performBlock:^{
            completion(nil);
        }];
    }];
}


- (void) uploadAvatarIfNeededForGroup:(Group*)group withCompletion:(CompletionBlock)completion{
    if ([group iAmAdmin]) {
        NSData * myAvatarData = group.avatar;
        if (myAvatarData != nil && myAvatarData.length>0) {
            NSString * myCurrentAvatarURL = group.avatarURL;
            if (myCurrentAvatarURL == nil || myCurrentAvatarURL.length == 0 || group.avatarUploadURL == nil) {
                [self getAvatarURLForGroup:group withCompletion:^(NSDictionary *urls) {
                    if (urls) {
                        [self uploadAvatar:myAvatarData toURL:urls[@"uploadUrl"] withDownloadURL:urls[@"downloadUrl"] inQueue:_avatarUploadQueue withCompletion:^(NSError *theError) {
                            if (theError != nil) {
                                NSLog(@"#ERROR: Avatar upload for group %@ failed, error=%@", group, theError);
                                completion(theError);
                            } else {
                                group.avatarURL = urls[@"downloadUrl"];
                                group.avatarUploadURL = urls[@"uploadUrl"];
                                completion(nil);
                            }
                        }];
                        return;
                    } else {
                        completion(nil);
                    }
                }];
                return;
            }
        }
    }
    completion(nil);
}

+ (NSString*)checkForceFilecacheUrl:(NSString*)theURL {
    NSString * forceFilecacheURL = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOForceFilecacheURL];
    if (forceFilecacheURL && ! [forceFilecacheURL isEqualToString: @""]) {
        NSURL * origURL = [NSURL URLWithString:theURL];
        NSURL * newBaseURL = [NSURL URLWithString:forceFilecacheURL];
        NSURLComponents * newURLComponents = [NSURLComponents new];
        newURLComponents.scheme = [newBaseURL scheme];
        newURLComponents.host = [newBaseURL host];
        newURLComponents.port = [newBaseURL port];
        newURLComponents.path = [origURL path];
        NSURL * newURL = [newURLComponents URL];
#ifdef DEBUG
        NSLog(@"force URL %@ => %@",theURL, newURL);
#endif
        return [newURL absoluteString];
    }
    return theURL;
}

- (void) uploadAvatar:(NSData*)avatar toURL: (NSString*)toURL withDownloadURL:(NSString*)downloadURL inQueue:(GCNetworkQueue*)queue withCompletion:(CompletionBlock)handler {
    if (CONNECTION_TRACE) {NSLog(@"uploadAvatar size %d uploadURL=%@, downloadURL=%@", avatar.length, toURL, downloadURL );}
    
    toURL = [HXOBackend checkForceFilecacheUrl:toURL];
    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:toURL HTTPMethod:@"PUT" parameters:nil];
    NSDictionary * headers = [self httpHeaderWithContentLength: avatar.length];
    for (NSString *key in headers) {
        [request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
    }
    [request addValue:self.delegate.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setHTTPBody:avatar];
    
    if (CONNECTION_TRACE) {NSLog(@"uploadAvatar: request header= %@",request.allHTTPHeaderFields);}
    GCHTTPRequestOperation *operation =
    [GCHTTPRequestOperation HTTPRequest:request
                          callBackQueue:nil
                      completionHandler:^(NSData *data, NSHTTPURLResponse *response) {
                          if (CONNECTION_TRACE) {
                              NSLog(@"uploadAvatar got response status = %d,(%@) headers=%@", response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"uploadAvatar response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode == 301 || response.statusCode == 308 || response.statusCode == 200) {
                              if (CONNECTION_TRACE) {NSLog(@"uploadAvatar: seems ok, lets check");}
                              [self checkUploadStatus:toURL hasSize:avatar.length withCompletion:^(NSString *url, BOOL ok) {
                                  if (ok) {
                                      handler(nil);
                                  } else {
                                      NSString * myDescription = @"uploadAvatar check failed";
                                      // NSLog(@"%@", myDescription);
                                      NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.avatar.upload" code: 947 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                                      handler(myError);
                                 }
                              }];
                              
                          } else {
                              NSString * myDescription = [NSString stringWithFormat:@"uploadAvatar irregular response status = %d, headers=%@", response.statusCode, response.allHeaderFields];
                              // NSLog(@"%@", myDescription);
                              NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.avatar.upload" code: 945 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                              handler(myError);
                          }
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"uploadAvatar error response status = %d, headers=%@, error=%@", response.statusCode, response.allHeaderFields, error);
                               handler(error);
                               
                           }
                       challengeHandler:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                           [self connection:connection willSendRequestForAuthenticationChallenge:challenge];
                       }
     ];
    if (queue == nil) {
        [operation startRequest];
    } else {
        [queue enqueueOperation:operation];
    }
}

+ (void) downloadDataFromURL:(NSString*)fromURL inQueue:(GCNetworkQueue*)queue withCompletion:(DataLoadedBlock)handler {
    if (CONNECTION_TRACE) {NSLog(@"downloadDataFromURL  %@", fromURL );}
    
    fromURL = [HXOBackend checkForceFilecacheUrl:fromURL];
    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:fromURL HTTPMethod:@"GET" parameters:nil];
    NSString * userAgent = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).userAgent;
    [request addValue:userAgent forHTTPHeaderField:@"User-Agent"];
    
    if (CONNECTION_TRACE) {NSLog(@"downloadDataFromURL: request header= %@",request.allHTTPHeaderFields);}
    GCHTTPRequestOperation *operation =
    [GCHTTPRequestOperation HTTPRequest:request
                          callBackQueue:nil
                      completionHandler:^(NSData *data, NSHTTPURLResponse *response) {
                          if (CONNECTION_TRACE) {
                              NSLog(@"downloadDataFromURL got response status = %d,(%@) headers=%@", response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"downloadDataFromURL response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode == 200) {
                              if (CONNECTION_TRACE) {NSLog(@"downloadDataFromURL: response 200 ok");}
                              if (data == nil || data.length == 0) {
                                  NSLog(@"#WARNING: downloadDataFromURL: status ok, but response data ist empty, URL=%@", request.URL);
                              }
                              NSString * contentLength = response.allHeaderFields[@"Content-Length"];
                              if (contentLength != nil && [contentLength integerValue] != data.length) {
                                  NSString * myDescription = [NSString stringWithFormat:@"downloadDataFromURL content length mismatch, header Content-Lenght = %@, data length = %d, headers=%@", contentLength, data.length, response.allHeaderFields];
                                  // NSLog(@"%@", myDescription);
                                  NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.download" code: 931 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                                  handler(data, myError);
                              } else {
                                  handler(data,nil);
                              }
                              
                          } else {
                              NSString * myDescription = [NSString stringWithFormat:@"downloadDataFromURL irregular response status = %d, headers=%@", response.statusCode, response.allHeaderFields];
                              // NSLog(@"%@", myDescription);
                              NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.download" code: 946 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                              handler(nil, myError);
                          }
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"downloadDataFromURL error response status = %d, headers=%@, error=%@", response.statusCode, response.allHeaderFields, error);
                               handler(nil, error);
                               
                           }
                       challengeHandler:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                           [[HXOBackend instance] connection:connection willSendRequestForAuthenticationChallenge:challenge];
                       }
     ];
    if (queue == nil) {
        [operation startRequest];
    } else {
        [queue enqueueOperation:operation];
    }
}


#pragma mark - Avatar uploading

-(void)makeSureAvatarUploaded {
    NSData * myAvatarData = [UserProfile sharedProfile].avatar;
    if (myAvatarData != nil && myAvatarData.length>0) {
        NSString * myCurrentAvatarURL = [UserProfile sharedProfile].avatarURL;
        NSString * myCurrentAvatarUploadURL = [UserProfile sharedProfile].avatarUploadURL;
        if (myCurrentAvatarURL != nil && myCurrentAvatarURL.length > 0) {
            if (myCurrentAvatarUploadURL != nil && myCurrentAvatarUploadURL.length > 0) {
                [self checkUploadStatus:myCurrentAvatarUploadURL hasSize:myAvatarData.length withCompletion:^(NSString *url, BOOL ok) {
                    if (!ok) {
                        [UserProfile sharedProfile].avatarURL = @"";
                        [self uploadAvatarIfNeededWithCompletion:^(BOOL didIt) {
                            [self modifyPresenceAvatarURLWithHandler:nil];
                        }];
                    }
                }];
            }
        }
    }
}

// completion will be called with YES when an upload has occured and succeeded, otherwise completion will be called with NO argument
// the caller must perform a presence update itself in the completion handler in case of a YES argument
- (void) uploadAvatarIfNeededWithCompletion:(GenericResultHandler)completion {
    NSData * myAvatarData = [UserProfile sharedProfile].avatar;
    if (myAvatarData != nil && myAvatarData.length>0) {
        NSString * myCurrentAvatarURL = [UserProfile sharedProfile].avatarURL;
        NSString * myCurrentAvatarUploadURL = [UserProfile sharedProfile].avatarUploadURL;
        if (myCurrentAvatarURL == nil || myCurrentAvatarURL.length == 0 || myCurrentAvatarUploadURL == nil) {
            [self getAvatarURLWithCompletion:^(NSDictionary *urls) {
                if (urls) {
                    [self uploadAvatar:myAvatarData toURL:urls[@"uploadUrl"] withDownloadURL:urls[@"downloadUrl"] inQueue:_avatarUploadQueue withCompletion:^(NSError *theError) {
                        if (theError != nil) {
                            NSLog(@"#ERROR: Avatar upload failed, error=%@", theError);
                            completion(NO);
                        } else {
                            NSLog(@"Avatar upload succeeded, lets check");
                            [self checkUploadStatus:urls[@"uploadUrl"] hasSize:myAvatarData.length withCompletion:^(NSString *url, BOOL ok) {
                                if (ok) {
                                    [UserProfile sharedProfile].avatarURL = urls[@"downloadUrl"];
                                    [UserProfile sharedProfile].avatarUploadURL = urls[@"uploadUrl"];
                                    NSLog(@"Avatar upload verified, is ok");
                                    completion(YES);
                                } else {
                                    completion(NO);
                                }
                            }];
                        }
                    }];
                } else {
                    NSLog(@"Failed to get Avatar upload urls");
                    completion(NO);
                }
            }];
        } else {
            completion(NO); // avatar is already upload
        }
    } else {
        completion(NO); // avatar is default, no update required
    }
}

/*
- (void) uploadAvatarIfNeeded {
    NSData * myAvatarData = [UserProfile sharedProfile].avatar;
    if (myAvatarData != nil && myAvatarData.length>0) {
        NSString * myCurrentAvatarURL = [UserProfile sharedProfile].avatarURL;
        if (myCurrentAvatarURL == nil || myCurrentAvatarURL.length == 0) {
            [self getAvatarURLWithCompletion:^(NSDictionary *urls) {
                if (urls) {
                    //[self uploadAvatarTo:urls[@"uploadUrl"] withDownloadURL:urls[@"downloadUrl"]];
                }
            }];
        }
    }
}
*/
/*
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
*/
-(NSDictionary*) httpHeaderWithContentLength: (NSUInteger) theLength {
	
    NSDictionary * headers = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSString stringWithFormat:@"%u", theLength], @"Content-Length",
                              nil
                              ];
    return headers;
    
}

- (void) getAvatarURLForGroup:(Group*) group withCompletion:(FileURLRequestHandler)handler {
    NSData * myAvatarImmutableData = group.avatar;
    if (myAvatarImmutableData == nil || [myAvatarImmutableData length] == 0) {
        handler(nil);
        return;
    }
    NSMutableData * myAvatarData = [NSMutableData dataWithData:myAvatarImmutableData];
    
    [self createFileForStorageWithSize:@(myAvatarData.length) completionHandler:^(NSDictionary *urls) {
        handler(urls);
    }];
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
}

+ (BOOL) allowUntrustedServerCertificate {
#ifdef DEBUG
    //return ![[Environment sharedEnvironment].currentEnvironment isEqualToString: @"production"];
    return [[[HXOUserDefaults standardUserDefaults] valueForKey: kHXODebugAllowUntrustedCertificates] boolValue];
#else
    return NO;
#endif
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust] && [challenge previousFailureCount] == 0 && [challenge proposedCredential] == nil)
    {
        if ([self connection:connection authenticationChallenge:challenge] || [HXOBackend allowUntrustedServerCertificate])
        {
            [[challenge sender] useCredential:[NSURLCredential credentialForTrust:[[challenge protectionSpace] serverTrust]] forAuthenticationChallenge:challenge];
        }
        else
        {
            [[challenge sender] cancelAuthenticationChallenge: challenge];
            [[challenge sender] performDefaultHandlingForAuthenticationChallenge:challenge];
        }
    }
}

// check if a server cert is in the set of pinned down certs [self certificates]
- (BOOL)connection:(NSURLConnection *)connection authenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
    
    NSArray * sslCerts = [self certificates];
    
    BOOL _pinnedCertFound = NO;
    
    if ([protectionSpace authenticationMethod] == NSURLAuthenticationMethodServerTrust) {
        SecTrustRef secTrust = [protectionSpace serverTrust];
        
        if (sslCerts != nil) {
            //SecTrustRef secTrust = (__bridge SecTrustRef)[aStream propertyForKey:(__bridge id)kCFStreamPropertySSLPeerTrust];
            if (secTrust) {
                NSInteger numCerts = SecTrustGetCertificateCount(secTrust);
                for (NSInteger i = 0; i < numCerts && !_pinnedCertFound; i++) {
                    SecCertificateRef cert = SecTrustGetCertificateAtIndex(secTrust, i);
                    NSData *certData = CFBridgingRelease(SecCertificateCopyData(cert));
                    
                    //NSLog(@"certData %d = %@", i, certData);
                    if (CHECK_CERTS_DEBUG) NSLog(@"Backend: connection: certData %d = len = %lu", i, (unsigned long)certData.length);
                    for (id ref in sslCerts) {
                        SecCertificateRef trustedCert = (__bridge SecCertificateRef)ref;
                        NSData *trustedCertData = CFBridgingRelease(SecCertificateCopyData(trustedCert));
                        
                        if (CHECK_CERTS_DEBUG) NSLog(@"Backend: connection: comparing with trustedCertData len %d", trustedCertData.length);
                        if ([trustedCertData isEqualToData:certData]) {
                            if (CHECK_CERTS_DEBUG) NSLog(@"Backend: connection: found pinnned cert len %lu", (unsigned long)trustedCertData.length);
                            _pinnedCertFound = YES;
                            break;
                        }
                    }
                }
            }
            return _pinnedCertFound;
        }
    }
    return NO;
}

#if 0
-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    if (connection == _avatarUploadConnection) {
        if (CONNECTION_TRACE) {
            NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
            NSLog(@"_avatarUploadConnection didReceiveResponse %@, status=%ld, %@", httpResponse, (long)[httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
        }
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
            [self updatePresenceWithHandler:^(BOOL ok) { }];
        } else {
            NSLog(@"ERROR: _avatarUploadConnection only uploaded %d bytes, should be %d",_avatarBytesUploaded, _avatarBytesTotal);
        }
    } else {
        NSLog(@"ERROR: Attachment _avatarUploadConnection connectionDidFinishLoading without valid connection");
    }
}
#endif


+ (BOOL)scanRange:(NSString*)theRange rangeStart:(long long*)rangeStart rangeEnd:(long long*)rangeEnd contentLength:(long long*)contentLength
{
    NSScanner * theScanner = [NSScanner scannerWithString:theRange];
    [theScanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@" ="]];
    return ([theScanner scanString:@"bytes" intoString:NULL] &&
            //[theScanner scanCharactersFromSet: intoString:NULL] &&
            [theScanner scanLongLong:rangeStart] &&
            [theScanner scanString:@"-" intoString:NULL] &&
            [theScanner scanLongLong:rangeEnd] &&
            [theScanner scanString:@"/" intoString:NULL] &&
            [theScanner scanLongLong:contentLength]
            );
}

- (void) checkUploadStatus:(NSString*)theURL hasSize:(long long)expectedSize withCompletion:(DataURLStatusHandler)handler {
    if (CHECK_URL_TRACE) {NSLog(@"checkUploadStatus uploadURL=%@, expectedSize=%lld", theURL, expectedSize );}
    
    theURL = [HXOBackend checkForceFilecacheUrl:theURL];
    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:theURL HTTPMethod:@"PUT" parameters:nil];
    NSDictionary * headers = @{@"Content-Length": @"0"};
    if (CHECK_URL_TRACE) {NSLog(@"checkUploadStatus: headers=%@", headers);}
	for (NSString *key in headers) {
		[request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
	}
	[request addValue:self.delegate.userAgent forHTTPHeaderField:@"User-Agent"];
    
    if (CHECK_URL_TRACE) {NSLog(@"checkUploadStatus: request header for check= %@",request.allHTTPHeaderFields);}
    GCHTTPRequestOperation *operation =
    [GCHTTPRequestOperation HTTPRequest:request
                          callBackQueue:nil
                      completionHandler:^(NSData *data, NSHTTPURLResponse *response) {
                          if (CHECK_URL_TRACE) {
                              NSLog(@"checkUploadStatus got response status = %d,(%@) headers=%@", response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode != 404) {
                              NSDictionary * myHeaders = response.allHeaderFields;
                              
                              NSString * myRangeString = myHeaders[@"Range"];
                              
                              if (myRangeString != nil) {
                                  
                                  long long rangeStart;
                                  long long rangeEnd;
                                  long long contentLength;
                                  
                                  if ([HXOBackend scanRange:myRangeString
                                                 rangeStart:&rangeStart
                                                   rangeEnd:&rangeEnd
                                              contentLength:&contentLength])
                                  {
                                      if (rangeEnd + 1 == expectedSize) {
                                          if (CHECK_URL_TRACE) NSLog(@"checkUploadStatus size %lld matches", rangeEnd+1);
                                          handler(theURL, YES);
                                          return;
                                      }
                                      NSLog(@"checkUploadStatus size returned %lld mismatch expected=%lld", rangeEnd+1, expectedSize);
                                  } else {
                                      NSLog(@"checkUploadStatus could not parse Content-Range Header, headers=%@", response.allHeaderFields);
                                  }
                              } else {
                                  NSString * ContentLength = myHeaders[@"Content-Length"];
                                  if (ContentLength != nil && [ContentLength integerValue] == 0) {
                                      NSLog(@"checkUploadStatus: empty data");
                                  } else {
                                      NSLog(@"checkUploadStatus irregular Content-Length %@, response status = %d, headers=%@",ContentLength, response.statusCode, response.allHeaderFields);
                                  }
                              }
                              handler(theURL, NO);
                              
                          } else {
                              NSLog(@"checkUploadStatus irregular response status = %d, headers=%@", response.statusCode, response.allHeaderFields);
                          }
                          handler(theURL, NO);
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"checkUploadStatus error response status = %d, headers=%@, error=%@", response.statusCode, response.allHeaderFields, error);
                               handler(theURL, NO);
                           }
                       challengeHandler:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                           [[HXOBackend instance] connection:connection willSendRequestForAuthenticationChallenge:challenge];
                       }
     ];
    [operation startRequest];
}


@end
