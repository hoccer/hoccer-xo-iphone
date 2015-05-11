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
#import "ModalTaskHUD.h"
#import "GCDAsyncUDPSocket.h"
#import "HXOLocalization.h"

#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>

#define DELIVERY_TRACE      NO
#define GLITCH_TRACE        NO
#define SECTION_TRACE       NO
#define CONNECTION_TRACE    NO
#define GROUPKEY_DEBUG      NO
#define GROUP_DEBUG         NO
#define RELATIONSHIP_DEBUG  NO
#define TRANSFER_DEBUG      NO
#define CHECK_URL_TRACE     NO
#define CHECK_CERTS_DEBUG   NO
#define DEBUG_DELETION      NO
#define LOCKING_TRACE       NO
#define PRESENCE_DEBUG      NO
#define SINGLE_NEARBY_DEBUG NO
#define TRACE_INSERT_LOCKING NO

#ifdef DEBUG
#define USE_VALIDATOR YES
#else
#define USE_VALIDATOR NO
#endif

#define FULL_HELLO
#define TRACE_TIME_DIFFERENCE YES

const NSString * const kHXOProtocol = @"com.hoccer.talk.v5";

const NSString * kqMessaging = @"messaging";
const NSString * kqContacts = @"contacts";

static const NSUInteger kHXOMaxCertificateVerificationErrors = 3;

static const NSUInteger     kHXOPairingTokenMaxUseCount = 10;
static const NSTimeInterval kHXOPairingTokenValidTime   = 60 * 60 * 24 * 7; // one week

static const int kMaxConcurrentDownloads = 2;
static const int kMaxConcurrentUploads = 2;

const double kHXgetServerTimeInterval = 10 * 60; // get Server Time every n minutes

NSString * const kNickTemporary       = @"<temporary>";
NSString * const kNickNewPresence     = @"<new presence>";
NSString * const kNickNewRelationship = @"<new relationship>";
NSString * const kNickNewMember       = @"<new member>";

typedef enum BackendStates {
    kBackendDisabling,
    kBackendDisabled,
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

    // these are only partially used yet
    GCNetworkQueue *   _attachmentDownloadQueue;
    GCNetworkQueue *   _attachmentUploadQueue;

    BOOL               _uncleanConnectionShutdown;
    
    NSMutableArray * _attachmentDownloadsWaiting;
    NSMutableArray * _attachmentUploadsWaiting;
    NSMutableArray * _attachmentDownloadsActive;
    NSMutableArray * _attachmentUploadsActive;
    BOOL            _locationUpdatePending;
    unsigned        _loginFailures;
    unsigned        _loginRefusals;
    NSMutableSet * _pendingGroupDeletions;
    NSMutableSet * _pendingDeliveryUpdates;
    NSMutableSet * _pendingAttachmentDeliveryUpdates;
    NSMutableSet * _postponedAttachmentDeliveryUpdates;
    NSMutableSet * _groupsNotYetPresentedInvitation;
    NSMutableSet * _groupsPresentingInvitation;
    NSMutableSet * _contactPresentingFriendMessage;
    NSMutableSet * _contactPresentingFriendInvitation;
    NSMutableSet * _insertionLocks;
    NSMutableSet * _syncTasks;
    
    GenericResultHandler _firstEnvironmentUpdateHandler;

    NSDate * _startedConnectingTime;
    GCDAsyncUdpSocket *_udpSocket ; // create this first part as a global variable
}

- (void) identify;

@end

@implementation HXOBackend

@dynamic isReady;

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
        _startedConnectingTime = nil;
        _pendingGroupDeletions = [NSMutableSet new];
        _pendingDeliveryUpdates = [NSMutableSet new];
        _pendingAttachmentDeliveryUpdates = [NSMutableSet new];
        _postponedAttachmentDeliveryUpdates = [NSMutableSet new];
        _groupsNotYetPresentedInvitation = [NSMutableSet new];
        _contactPresentingFriendMessage = [NSMutableSet new];
        _contactPresentingFriendInvitation = [NSMutableSet new];
        _insertionLocks = [NSMutableSet new];
        _syncTasks = [NSMutableSet new];
        
        _firstConnectionAfterCrashOrUpdate = theAppDelegate.launchedAfterCrash || theAppDelegate.runningNewBuild;
        
        _avatarDownloadQueue = [[GCNetworkQueue alloc] init];
        [_avatarDownloadQueue setMaximumConcurrentOperationsCount:1];
        [_avatarDownloadQueue enableNetworkActivityIndicator:YES];
        
        _avatarUploadQueue = [[GCNetworkQueue alloc] init];
        [_avatarUploadQueue setMaximumConcurrentOperationsCount:1];
        [_avatarUploadQueue enableNetworkActivityIndicator:YES];

        _attachmentDownloadQueue = [[GCNetworkQueue alloc] init];
        [_attachmentDownloadQueue setMaximumConcurrentOperationsCount:1];
        [_avatarDownloadQueue enableNetworkActivityIndicator:YES];
        
        _attachmentUploadQueue = [[GCNetworkQueue alloc] init];
        [_attachmentUploadQueue setMaximumConcurrentOperationsCount:1];
        [_attachmentUploadQueue enableNetworkActivityIndicator:YES];

        
        [_serverConnection registerIncomingCall: @"incomingDelivery"    withSelector:@selector(incomingDelivery:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"incomingDeliveryUpdated" withSelector:@selector(incomingDeliveryUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"outgoingDeliveryUpdated" withSelector:@selector(outgoingDeliveryUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"pushNotRegistered"   withSelector:@selector(pushNotRegistered:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"presenceUpdated"     withSelector:@selector(presenceUpdatedNotification:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"presenceModified"     withSelector:@selector(presenceModifiedNotification:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"relationshipUpdated" withSelector:@selector(relationshipUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"groupUpdated"        withSelector:@selector(groupUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"groupMemberUpdated"  withSelector:@selector(groupMemberUpdated:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"ping"                withSelector:@selector(ping) isNotification: NO];
        [_serverConnection registerIncomingCall: @"getEncryptedGroupKeys" withSelector:@selector(getEncryptedGroupKeys:withResponder:) asyncResult:YES];
        [_serverConnection registerIncomingCall: @"alertUser"           withSelector:@selector(alertUser:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"settingsChanged"      withSelector:@selector(settingsChanged:) isNotification: YES];
        [_serverConnection registerIncomingCall: @"deliveriesReady"      withSelector:@selector(deliveriesReady) isNotification: YES];
        
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
                default:
                    NSLog(@"Reachable status=%d", status);
                    [self checkReconnect];
                    break;
                   
            }
            
        };
        
        _internetConnectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kGCNetworkReachabilityDidChangeNotification
                                                                                        object:nil
                                                                                         queue:[NSOperationQueue mainQueue]
                                                                                    usingBlock:reachablityBlock];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults addObserver:self
                   forKeyPath:kHXOAnonymousNotifications
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
        [defaults addObserver:self
                   forKeyPath:kHXOAccessControlPhotoEnabled
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
        [defaults addObserver:self
                   forKeyPath:kHXOWorldwideNotifications
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
        [defaults addObserver:self
                   forKeyPath:kHXOWorldwideTimeToLive
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
        
        _attachmentDownloadsWaiting = [[NSMutableArray alloc] init];
        _attachmentUploadsWaiting = [[NSMutableArray alloc] init];
        _attachmentDownloadsActive = [[NSMutableArray alloc] init];
        _attachmentUploadsActive = [[NSMutableArray alloc] init];
        
        _locationUpdatePending = NO;
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    
    return self;
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context
{
    NSLog(@"HXOBackend KVO: %@ changed property %@ to value %@", object, keyPath, change);
    if ([keyPath isEqualToString:kHXOAnonymousNotifications]) {
        if (self.isReady) {
            [self setApnsMode];
        }
    }
    if ([keyPath isEqualToString:kHXOAccessControlPhotoEnabled]) {
        if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOAccessControlPhotoEnabled]) {
            if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    // Will get here on both iOS 7 & 8 even though camera permissions weren't required
                    // until iOS 8. So for iOS 7 permission will always be granted.
                    if (granted) {
                        // Permission has been granted. Use dispatch_async for any UI updating
                        // code because this block may be executed in a thread.
                        //dispatch_async(dispatch_get_main_queue(), ^{
                        //    [self showCameraPickerForType:type];
                        //});
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [AppDelegate.instance showGenericAlertWithTitle:@"permission_denied_title"
                                                                 andMessage:HXOLocalizedString(@"permission_denied_camera_attachment", nil, HXOAppName())
                                                                withOKBlock:^{}];
                        });
                    }
                }];
            } else {
                // We are on iOS <= 6. Just do what we need to do.
                // [self showCameraPickerForType:type];
            }
        }
    }
    if ([keyPath isEqualToString:kHXOWorldwideNotifications] || [keyPath isEqualToString:kHXOWorldwideTimeToLive]) {
        if (HXOEnvironment.sharedInstance.activationMode == ACTIVATION_MODE_WORLDWIDE && self.isReady) {
            [self sendEnvironmentUpdate];
        }
    }
}

- (GCNetworkQueue *)attachmentUploadQueue {
    return _attachmentUploadQueue;
}

- (GCNetworkQueue *)attachmentDownloadQueue {
    return _attachmentDownloadQueue;
}

-(NSString*)insertionLock:(NSString*)name {
    if (name == nil) {
        NSLog(@"#ERROR: insertionLock called with nil name, stack=%@", [NSThread callStackSymbols]);
        name = @"NIL-LOCK";
    }
    
    @synchronized(_insertionLocks) {
        NSString * lock = [_insertionLocks member:name];
        if (lock != nil) {
            if (TRACE_INSERT_LOCKING) NSLog(@"handing out insertion lock %@",lock);
            return lock;
        }
        lock = [NSString stringWithString:name];
        [_insertionLocks addObject:lock];
        if (TRACE_INSERT_LOCKING) NSLog(@"handing out new insertionlock %@",lock);
        return lock;
    }
}

-(BOOL)isReady {
    return _state == kBackendReady;
}

-(void)sendEnvironmentDestroyWithType:(NSString*)type {
    if (_state == kBackendReady && !_locationUpdatePending) {
        if (_state == kBackendReady) {
            if ([kGroupTypeNearby isEqualToString:type]) {
                [self destroyEnvironmentType:type withHandler:^(BOOL ok) {
                    if (SINGLE_NEARBY_DEBUG) NSLog(@"Enviroment type %@ destroyed = %d",type, ok);
                }];
            } else {
                [self releaseEnvironmentType:type withHandler:^(BOOL ok) {
                    if (SINGLE_NEARBY_DEBUG) NSLog(@"Enviroment type %@ released = %d",type, ok);
                }];
            }
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
        case kBackendDisabled:
            return @"backend_disabled";
            break;
        case kBackendDisabling:
            return @"backend_disabling";
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
    BOOL disabled = NO;
    BOOL reachable = [self.delegate.internetReachabilty isReachable];
    if (reachable) {
        newInfo = [self stateString: _state];
        normal = (_state == kBackendReady) ;
        disabled = (_state == kBackendDisabling || _state == kBackendDisabled) ;
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
    if (normal || progress || !reachable || disabled) {
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
        if (CONNECTION_TRACE) NSLog(@"canceling Timer for %@",_stateNotificationDelayTimer.userInfo);
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

// send a udp packet in order to wake up/activate the network interface on some devices
-(void)sendUDPPacket:(NSString*)string {
    NSLog(@"Sending udp packet %@", string);
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding ];
    [_udpSocket sendData:data toHost:@"www.hoccer.com" port:9999 withTimeout:-1 tag:1];
}

- (void)udpSocket:(GCDAsyncUdpSocket*)socket didConnectToAddress:(NSData *)address {
    NSLog(@"udp socket didConnectToAddress: %@",address);
}

- (void)udpSocket:(GCDAsyncUdpSocket*)socket didNotConnect:(NSError *)error {
    NSLog(@"udp socket didNotConnect: %@",error);
}

- (void)udpSocket:(GCDAsyncUdpSocket*)socket didSendDataWithTag:(long)tag {
    NSLog(@"udp socket didSendDataWithTag: %ld",tag);
}

- (void)udpSocket:(GCDAsyncUdpSocket*)socket didNotSendDataWithTag:(long)tag dueToError:(NSError *)error{
    NSLog(@"udp socket didNotSendDataWithTag: %ld dueToError %@",tag, error);
}

- (void)udpSocket:(GCDAsyncUdpSocket*)socket didReceiveData:(NSData *)data fromAddress:(NSData*)address withFilterContext:(id)context {
    NSLog(@"udp socket didReceiveData: %@ fromAdress %@ withFilter %@",data,address,context);
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket*)socket withError:(NSError *)error {
    NSLog(@"udpSocketDidClose: withError: %@",error);
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

// calls sendmessage after cloning the attachment
- (void) forwardMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment {
    
    Attachment * newAttachment = nil;
    
    AttachmentCompletionBlock completion  = ^(Attachment * myAttachment, NSError *myerror) {
        if (myerror == nil) {
            [self sendMessage:text toContactOrGroup:contact toGroupMemberOnly:privateGroupMessageContact withAttachment:myAttachment];
        }
    };
    
    newAttachment = [attachment cloneWithCompletion:completion];
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
    BOOL deliveryFailed = delivery.isFailure;
    if (_state == kBackendReady && ! deliveryFailed) {
        [self outDeliveryRequest: message withDeliveries: @[delivery] withCompletion:^(BOOL ok) {
            if (ok) {
                [SoundEffectPlayer messageSent];
                if (attachment != nil && attachment.state == kAttachmentWantsTransfer && ! deliveryFailed) {
                    [self enqueueUploadOfAttachment:attachment];
                }
                [AppDelegate.instance saveContext];
            }
        }];
    } else {
        [AppDelegate.instance saveContext];
    }
}

- (NSString*)chatLockForSenderId:(NSString *)senderId andGroupId:(NSString*)groupId {
    NSString * contactId;
    if (groupId != nil) {
        contactId = groupId;
    } else {
        contactId = senderId;
    }
    NSString * lockId = [@"Chat-" stringByAppendingString:contactId];
    return lockId;
}

// TODO: contact should be an array of contacts
- (void) sendMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment {
    
    if (text == nil) {
        NSLog(@"ERROR: sendMessage text is nil");
        return;
    }
    
    if (contact == nil) {
        NSLog(@"ERROR: sendMessage contact is nil");
        return;
    }
    
    if (attachment != nil) {
        if ([AppDelegate.instance hasManagedObjectBeenDeleted:attachment] || [attachment fileUnavailable]) {
            [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"attachment_not_available_message",nil) withTitle:NSLocalizedString(@"attachment_not_available_title",nil) withOKBlock:^{
            }];
            if (![AppDelegate.instance hasManagedObjectBeenDeleted:attachment]) {
                [AppDelegate.instance deleteObject:attachment];
            }
            return;
        }
    }
    
    //NSString * lockId = [self chatLockForSenderId:[UserProfile sharedProfile].clientId andGroupId: contact.isGroup ? contact.clientId : nil];
    
    NSManagedObjectID * contactId = contact.objectID;
    NSManagedObjectID * privateContactId = privateGroupMessageContact.objectID;
    NSManagedObjectID * attachmentId = attachment.objectID;
    
    //[self.delegate performWithLockingId:lockId inNewBackgroundContext:^(NSManagedObjectContext *context) {
    [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        Contact * contact = (Contact *)[context objectWithID:contactId];
        Contact * privateGroupMessageContact = privateContactId == nil ? nil : (Contact *)[context objectWithID:privateContactId];
        Attachment * attachment = attachmentId == nil ? nil : (Attachment*)[context objectWithID:attachmentId];
        
        HXOMessage * message =  (HXOMessage*)[NSEntityDescription insertNewObjectForEntityForName: [HXOMessage entityName] inManagedObjectContext: context];
        message.body = text;
        message.timeSent = [self estimatedServerTime]; // [NSDate date];
        message.contact = contact;
        message.timeAccepted = [self estimatedServerTime];
        message.isOutgoingFlag = @YES;
        // message.timeSection = [contact sectionTimeForMessageTime: message.timeSent];
        message.messageId = @"";
        //message.messageTag = [NSString stringWithUUID];
        message.senderId = [UserProfile sharedProfile].clientId;
        message.isRead = YES;
        
        Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: context];
        [message.deliveries addObject: delivery];
        delivery.message = message;
        delivery.state = kDeliveryStateNew;
        
        if (contact.isGroup) {
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
            delivery.attachmentState = kDelivery_ATTACHMENT_STATE_NEW;
            [AppDelegate.instance saveContext:context];
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[message] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                [self createUrlsForTransferOfAttachmentOfMessage:managedObjects[0]];
            }];
            return;
        }
        delivery.attachmentState = kDelivery_ATTACHMENT_STATE_NONE;
        [AppDelegate.instance saveContext:context];
        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[message, delivery] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
            HXOMessage * message = managedObjects[0];
            Delivery * delivery = managedObjects[1];
            [self finishSendMessage:message toContact:message.contact withDelivery:delivery withAttachment:message.attachment];
        }];
    }];
}

- (void) createUrlsForTransferOfAttachmentOfMessage:(HXOMessage*)message {
    if (CONNECTION_TRACE) {NSLog(@"createUrlsForTransferOfAttachmentOfMessage: %@", message);}
    Attachment * attachment = message.attachment;
    if (attachment != nil) {
        [self createFileForTransferWithSize:attachment.cipheredSize completionHandler:^(NSDictionary *urls) {
            if (urls && [urls[@"uploadUrl"] length]>0 && [urls[@"downloadUrl"] length]>0 && [urls[@"fileId"] length]>0) {
                if (CONNECTION_TRACE) NSLog(@"createUrlsForTransferOfAttachmentOfMessage: got attachment urls=%@", urls);
                attachment.uploadURL = urls[@"uploadUrl"];
                attachment.remoteURL = urls[@"downloadUrl"];
                message.attachmentFileId = urls[@"fileId"];
                attachment.transferSize = @(0);
                attachment.cipherTransferSize = @(0);
                [AppDelegate.instance saveContext];
                // NSLog(@"sendMessage: message.attachment = %@", message.attachment);
                [self finishSendMessage:message toContact:message.contact withDelivery:message.deliveries.anyObject withAttachment:attachment];
            } else {
                NSLog(@"ERROR: Could not get attachment urls, retrying");
                [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(retryCreateUrlsForTransferOfAttachment:) userInfo:message repeats:NO];
            }
        }];
    } else {
        NSLog(@"ERROR: createUrlsForTransferOfAttachmentOfMessage: message without attachment");
    }
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

-(HXOMessage*) getMessageByAttachmentFileId:(NSString*)fileId inContext:(NSManagedObjectContext*) context {
    NSError *error;
    NSDictionary * vars = @{ @"attachmentFileId" : fileId};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"MessageByAttachmentFileId" substitutionVariables: vars];
    NSArray *messages = [context executeFetchRequest:fetchRequest error:&error];
    if (messages == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    if (messages.count > 0) {
        if (messages.count != 1) {
            NSLog(@"ERROR: Database corrupted, duplicate messages with attachmentFileId %@ in database", fileId);
            return nil;
        }
        HXOMessage * message = messages[0];
        return message;
    }
    return nil;
}

-(HXOMessage*) getMessageByTag:(NSString*)messageTag inContext:(NSManagedObjectContext*) context {
    NSError *error;
    NSDictionary * vars = @{ @"messageTag" : messageTag};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"MessageByMessageTag" substitutionVariables: vars];
    NSArray *messages = [context executeFetchRequest:fetchRequest error:&error];
    if (messages == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    if (messages.count > 0) {
        if (messages.count != 1) {
            NSLog(@"ERROR: Database corrupted, duplicate messages with tag %@ in database", messageTag);
            return nil;
        }
        HXOMessage * message = messages[0];
        return message;
    }
    return nil;
}

- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary {
    
    NSString * myMessageId = messageDictionary[@"messageId"];
    NSString * groupId = deliveryDictionary[@"groupId"];
    NSString * senderId = deliveryDictionary[@"senderId"];
    
    if (myMessageId == nil) {
        NSLog(@"ERROR: receiveMessage: missing messageId");
        return;
    }
    
    // we need to log all message in chat to avoid timeSection problems
    // (when acceptedTime is set, the timesection of other messages will be touched, too)

    [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
        if (DELIVERY_TRACE) NSLog(@"receiveMessage");
        if (USE_VALIDATOR) [self validateObject: messageDictionary forEntity:@"RPC_TalkMessage_in"];  // TODO: Handle Validation Error
        if (USE_VALIDATOR) [self validateObject: deliveryDictionary forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
        NSError *error;
        NSDictionary * vars = @{ @"messageId" : myMessageId};
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
            
            NSLog(@"receiveMessage: scheduling deliveryConfirm");
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[oldMessage, oldDelivery] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                NSLog(@"receiveMessage: starting deliveryConfirm on old");
                HXOMessage * oldMessage = (HXOMessage *)managedObjects[0];
                Delivery * oldDelivery = (Delivery *)managedObjects[1];
                [self inDeliveryConfirmMessage:oldMessage withDelivery:oldDelivery];
                NSLog(@"receiveMessage: done deliveryConfirm on old");
            }];
            return;
        }
        
        if (![deliveryDictionary[@"keyCiphertext"] isKindOfClass:[NSString class]]) {
            NSLog(@"ERROR: receiveMessage: rejecting received message without keyCiphertext, id= %@", vars[@"messageId"]);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self inDeliveryReject:messageDictionary[@"messageId"] withReason:@"no keyCiphertext in message"];
            }];
            return;
        }
        
        SecKeyRef myPrivateKeyRef = [[CCRSA sharedInstance] getPrivateKeyRefForPublicKeyIdString:deliveryDictionary[@"keyId"]];
        if (myPrivateKeyRef == NULL) {
            NSLog(@"ERROR: receiveMessage: rejecting received message with bad keyId (I have no matching private key) = %@, my keyId = %@", deliveryDictionary[@"keyId"],[[UserProfile sharedProfile] publicKeyId]);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self inDeliveryReject:messageDictionary[@"messageId"] withReason:@"bad keyId (no matching private key to decrypt incoming message)"];
            }];
            return;
        }
        
        if (DELIVERY_TRACE) NSLog(@"receiveMessage: inserting new message and delivery");
        HXOMessage * message = [NSEntityDescription insertNewObjectForEntityForName: [HXOMessage entityName] inManagedObjectContext: context];
        Delivery * delivery = [NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: context];
        //AUTOREL [message.deliveries addObject: delivery];
        delivery.message = message;
        
        Attachment * attachment = nil;
        if (messageDictionary[@"attachment"] != nil) {
            attachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: context];
            message.attachment = attachment;
        }
        
        //NSString * groupId = deliveryDictionary[@"groupId"];
        //NSString * senderId = deliveryDictionary[@"senderId"];
        NSString * receiverId = deliveryDictionary[@"receiverId"];
        
        Contact * sender = [self getContactByClientId:senderId inContext:context];
        Contact * receiver = [self getContactByClientId:receiverId inContext:context]; // will be nil for incoming messages because our contact is not in the database
        Group * group = nil;
        if (groupId != nil) {
            group = [self getGroupById:groupId inContext:context];
        }
        
        // Abort messages from unknown sender. This happens if someone becomes a member of a group,
        // sends some messages and leaves the group again while this client is offline.
        // There is a small possibilty of message loss, though. It happens if a message by some client
        // to a group arrives before the membership is known to this client.
        if (sender == nil || (groupId != nil && group == nil)) {
            NSString * reason = @"";
            if (sender == nil) {
                reason = [NSString stringWithFormat: @"{Unknown sender id %@}", senderId];
            } else {
                reason = [NSString stringWithFormat: @"{Known sender with name %@ relation %@ id %@}", sender.nickName, sender.relationshipState, sender.clientId];
            }
            if (groupId != nil && group == nil) {
                reason = [NSString stringWithFormat: @"%@{Unknown group id %@}", reason, groupId];
            }
            NSLog(@"Rejecting strange incoming message, reason= %@",reason);
            
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self inDeliveryReject:messageDictionary[@"messageId"] withReason:reason];
            }];
            [AppDelegate.instance deleteObject:message inContext:context];
            [AppDelegate.instance deleteObject:delivery inContext:context];
            return;
        }
        if (DELIVERY_TRACE) NSLog(@"receiveMessage: bulding stuff started");
        Contact * contact = nil;
        if (group != nil) {
            contact = group;
        } else {
            contact = sender;
        }
        
        message.isOutgoing = NO;
        message.isRead = NO;
        message.timeReceived = [self estimatedServerTime];
        // message.timeSection = [contact sectionTimeForMessageTime: message.timeAccepted];
        message.timeSection = message.timeAccepted;
        message.contact = contact;
        contact.rememberedLastVisibleChatCell = nil; // make view to scroll to end when user enters chat
        [contact.messages addObject: message];
        
        delivery.receiver = receiver; // will be nil for incoming messages because our contact is not in the database
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
                    NSLog(@"INFO: Message hmac is ok for id %@", message.messageId);
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
        
        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[contact]
                                                                                  withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)
        {
            Contact * contact = managedObjects[0];
            [context refreshObject: contact mergeChanges: YES];
            if (![self.delegate isInspecting:contact]) {
                // make chat to scroll to bottom when a new message is received
                //NSLog(@"clearing rememberedLastVisibleChatCell");
                contact.rememberedLastVisibleChatCell = nil;
            }
        }];

        if (DELIVERY_TRACE) NSLog(@"receiveMessage: scheduling new deliveryConfirm");
        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[message, delivery]
                                                                                  withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)
         {
            if (DELIVERY_TRACE) NSLog(@"receiveMessage: starting new deliveryConfirm");
            HXOMessage * message = (HXOMessage *)managedObjects[0];
            Delivery * delivery = (Delivery *)(HXOMessage *)managedObjects[1];
            Attachment * attachment = message.attachment;
             
             if (delivery.attachmentDownloadable) {
                 [self enqueueDownloadOfAttachment:attachment];
             }

            if (DELIVERY_TRACE) {NSLog(@"receiveMessage: confirming new message & delivery with state '%@' for tag %@ id %@",delivery.state, delivery.message.messageTag, message.messageId);}
            
             [self inDeliveryConfirmMessage: message withDelivery: delivery];
             
            if (message.attachment == nil) {
                [SoundEffectPlayer messageArrived];
            }
            //[self checkTransferQueues];
            
            id userInfo = @{ @"message":message };
            [[NSNotificationCenter defaultCenter] postNotificationName:@"receivedNewHXOMessage"
                                                                object:self
                                                              userInfo:userInfo
             ];
        }];
    }];
}

- (void)inDeliveryConfirmMessage:(HXOMessage *)message withDelivery:(Delivery *)delivery {
    if (_state == kBackendReady) {
        if ([[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOConfirmMessagesSeen] boolValue]) {
            if (message.isRead) {
                [self inDeliveryConfirmSeen: message.messageId withDelivery:delivery];
            } else {
                [self inDeliveryConfirmUnseen: message.messageId withDelivery:delivery];
            }
        } else {
            [self inDeliveryConfirmPrivate:message.messageId withDelivery:delivery];
        }
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
        [UserProfile.sharedProfile backupCredentials];
        _performRegistration = NO;
        [self startAuthentication];
    }
}


- (void)handleLoginError:(id)errorReturned inPhase:(NSString*)phase {
    NSLog(@"SRP phase %@ failed", phase);
    // can happen if the client thinks the connection was closed, but the server still considers it as open
    // so let us also close and try again
    
    NSString * errorMessage;
    if (errorReturned == nil) {
        errorMessage = @"unknown error";
    } else if ([errorReturned isKindOfClass:[NSDictionary class]]) {
        errorMessage = ((NSDictionary*)errorReturned)[@"message"];
    } else {
        errorMessage = [errorReturned description];
    }
    
    if (errorReturned != nil &&
        ([errorMessage isEqualToString:@"No such client"] ||
         [errorMessage isEqualToString:@"Authentication failed"] ||
         [errorMessage isEqualToString:@"Verification failed"] ||
         [errorMessage isEqualToString:@"Bad salt"] ||
         [errorMessage isEqualToString:@"Client deleted"] ||
         [errorMessage isEqualToString:@"Not registered"] ))
    {
        // check if our credentials were refused
        NSLog(@"Login credentials refused in SRP phase %@ with ‘%@', loginRefusals=%d", phase, errorMessage, _loginRefusals);
        _loginRefusals++;
        if (_loginRefusals >= 3) {
            [AppDelegate.instance showInvalidCredentialsWithInfo:errorMessage withContinueHandler:^{
            }];
            [self disable];
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
    
}

- (void) startAuthentication {
    [self setState: kBackendAuthenticating];
    NSString * A = [[UserProfile sharedProfile] startSrpAuthentication];
    [self srpPhase1WithClientId: [UserProfile sharedProfile].clientId A: A andHandler:^(NSString * challenge, NSDictionary * errorReturned) {
        if (challenge == nil) {
            [self handleLoginError:errorReturned inPhase:@"1"];
        } else {
            NSError * error;
            NSString * M = [[UserProfile sharedProfile] processSrpChallenge: challenge error: &error];
            if (M == nil) {
                NSLog(@"%@", error);
                // possible tampering ... trigger reconnect by closing the socket
                [self handleLoginError:error inPhase:@"2.5"];
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
                        [self handleLoginError:errorReturned inPhase:@"2"];
                        //[self didFinishLogin: NO];
                    }
                }];
            }
        }
    }];
}

-(void)startSync {
    _firstEnvironmentUpdateHandler = nil;
    if ([self quickStart]) {
        [self performParallelSync];
    } else {
        [self postLoginSynchronize];
    }
}

- (void) didFinishLogin: (BOOL) authenticated{
    if (authenticated) {
        // NSLog(@"identify(): got result: %@", responseOrError);
        if (_apnsDeviceToken) {
            [self registerApns: _apnsDeviceToken];
            _apnsDeviceToken = nil; // XXX: this is not nice...
        }
        [self setState: kBackendReady];

#define CHANGE_VERIFIER
#ifdef CHANGE_VERIFIER
        if ([[UserProfile sharedProfile] verfierChangeRequested]) {
            [self srpChangeVerifierWithHandler:^(BOOL ok) {
                if (ok) {
                    [[UserProfile sharedProfile] verfierChangeDone];
                }
                [self stopAndRetry];
            }];
            return;
        }
#endif
        
        if (HXOEnvironment.sharedInstance.activationMode != ACTIVATION_MODE_NONE && !AppDelegate.instance.runningInBackground) {
            NSLog(@"Nearby or worldwide active, defering sync until environment update ready");
            __block __typeof(self) __weak weakSelf = self;
            _firstEnvironmentUpdateHandler = ^(BOOL ok) {
                if (ok) {
                    [weakSelf startSync];
                } else {
                    [weakSelf stopAndRetry];
                }
            };
        } else {
            [self startSync];
        }
    } else {
        [self stopAndRetry];
    }
}

-(void)syncFailed {
    [self stopAndRetry];
}

-(void)initSyncTasks {
    [_syncTasks removeAllObjects];
}


-(void)beginSync:(NSString*)task {
    if ([_syncTasks containsObject:task]) {
        NSLog(@"#ERROR: syncTask %@ already began", task);
        return;
    }
    [_syncTasks addObject:task];
    NSLog(@"beginSync %@", task);
}

-(void)endSync:(NSString*)task {
    if (![_syncTasks containsObject:task]) {
        NSLog(@"#ERROR: syncTask %@ has not began", task);
        return;
    }
    [_syncTasks removeObject:task];
    NSLog(@"endSync %@", task);
    if (_syncTasks.count == 0) {
        NSLog(@"Sync finished");
        [self finishParallelSync];
    }
}

- (void)finishParallelSync {
    [self ready:^(BOOL ok)   {
        if (!ok) [self syncFailed];
    }];
    
    [self finishFirstConnectionAfterCrashOrUpdate];
    [self flushPendingMessages];
    [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self flushIncomingDeliveriesInContext:context];
    }];
    [self flushPendingFiletransfers];
    [AppDelegate.instance setupDocumentDirectoryMonitoring];

}

- (void)performParallelSync {
    
    BOOL forced = self.firstConnectionAfterCrashOrUpdate||[self fullSync];
    if (forced) {
        NSLog(@"Running forced full sync");
    }
    [self initSyncTasks];
    
    [self beginSync:@"hello"];
    [self helloWithCompletion:^(BOOL ok) {
        if (ok) [self endSync:@"hello"];
        else [self syncFailed];
    }];
    
    [self beginSync:@"syncPresences"];
    [self syncPresencesWithForce:forced withCompletion:^(BOOL ok) {
        if (ok) [self endSync:@"syncPresences"];
        else [self syncFailed];
    }];
    
    [self beginSync:@"syncRelationships"];
    [self syncRelationshipsWithForce:forced withCompletion:^(BOOL ok) {
        if (ok) [self endSync:@"syncRelationships"];
        else [self syncFailed];
    }];
    [self flushPendingInvites];
    
    [self beginSync:@"verifyKey"];
        [self verifyKeyWithHandler:^(BOOL keyOk, BOOL ok) {
        if (ok) {
            [self endSync:@"verifyKey"];
            if (!keyOk) {
                [self beginSync:@"updateKey"];
                [self updateKeyWithHandler:^(BOOL ok) {
                    if (ok) [self endSync:@"updateKey"];
                    else [self syncFailed];
                }];
            }
        } else {
            [self syncFailed];
        }
    }];
    
    [self beginSync:@"updatePresence"];
    [self updatePresenceWithHandler:^(BOOL ok) {
        if (ok) [self endSync:@"updatePresence"];
        else [self syncFailed];
    }];
    
    [self beginSync:@"syncGroups"];
    [self syncGroupsWithForce:forced withCompletion:^(BOOL ok) {
        if (!ok) [self syncFailed];
        else {
            [self endSync:@"syncGroups"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"postLoginSyncCompleted"
                                                                object:self
                                                              userInfo:nil
             ];
            if (AppDelegate.instance.conversationViewController !=nil && AppDelegate.instance.conversationViewController.environmentMode != ACTIVATION_MODE_NONE) {
                [HXOEnvironment.sharedInstance setActivation:AppDelegate.instance.conversationViewController.environmentMode];
            }
        }
    }];

}

- (void)postLoginSynchronize {
    BOOL forced = self.firstConnectionAfterCrashOrUpdate||[self fullSync];
    if (forced) {
        NSLog(@"Running forced full sync");
    }
    [self helloWithCompletion:nil];
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
            [self syncGroupsWithForce:forced withCompletion:^(BOOL ok2) {
                if (ok2) {
                    [self ready:^(BOOL ok3) {
                        if (ok3) {
                            [self finishFirstConnectionAfterCrashOrUpdate];
                            [self flushPendingMessages];
                            [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
                                [self flushIncomingDeliveriesInContext:context];
                            }];
                            [self flushPendingFiletransfers];
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"postLoginSyncCompleted"
                                                                                object:self
                                                                              userInfo:nil
                             ];
                            
                            [AppDelegate.instance setupDocumentDirectoryMonitoring];
                            
                            if (AppDelegate.instance.conversationViewController !=nil && AppDelegate.instance.conversationViewController.environmentMode != ACTIVATION_MODE_NONE) {
                                [HXOEnvironment.sharedInstance setActivation:AppDelegate.instance.conversationViewController.environmentMode];
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
    [self disableFullSync];
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
    if (_state == kBackendDisabled) {
        NSLog(@"Backend disabled, not starting");
        [self setState:kBackendDisabled];
        return;
    }
    _performRegistration = performRegistration;
    [self setState: kBackendConnecting];
    _startedConnectingTime = [NSDate new];
    [_serverConnection openWithURLRequest: [self urlRequest] protocols: @[kHXOProtocol] allowUntrustedConnections:[HXOBackend allowUntrustedServerCertificate]];
}

- (void)disable {
    if (_state != kBackendStopped) {
        [self setState:kBackendDisabling];
        [self stop];
        
    } else {
        [self setState:kBackendDisabled];
    }
}

- (void)enable {
    if (_state == kBackendDisabled || _state != kBackendDisabling) {
        [self setState:kBackendStopped];
    }
}

- (void) stop {
    if (_state != kBackendStopped && _state != kBackendDisabled) {
        if (_state != kBackendDisabling) {
            [self setState: kBackendStopping];
        }
        [_serverConnection close];
        [self clearWaitingAttachmentTransfers];
    }
}

- (void) stopAndRetry {
    if (_state != kBackendDisabled && _state != kBackendDisabling) {
        [self setState: kBackendStopped];
        [_serverConnection close];
    }
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
            if (!ok && [self getBackendState] == kBackendReady) {
                // we still believe to be connected, but bing failed
                NSLog(@"checkReconnect: bing failed, disconnect and start over");
                [self disconnect];
                [self reconnect];
            }
            if (_state == kBackendStopped) {
                NSLog(@"checkReconnect: backend now stopped, try reconnecting");
                [self reconnect];
            }
        }];
    } else if (_state == kBackendConnecting) {
        if (_startedConnectingTime.timeIntervalSinceNow < - 5.0) {
            NSLog(@"checkReconnect: backend takes too long to connect, reconnect");
            [self reconnect];
        }
    } else {
        NSLog(@"checkReconnect: backend in state %@, doing nothing", [self stateString: _state]);
    }
}

- (void) reconnect {
    [self sendUDPPacket:@"TEST"];
    if (_reconnectTimer != nil) {
        [_reconnectTimer invalidate];
        _reconnectTimer = nil;
    }
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if ((state == UIApplicationStateBackground || state == UIApplicationStateInactive) && !self.delegate.processingBackgroundNotification)
    {
        // do not reconnect when in background
        NSLog(@"reconnect: not reconnecting because app is in background");
       return;
    }
    if ([self.delegate.internetReachabilty isReachable]) {
        [self start: _performRegistration];
    } else {
        NSLog(@"reconnect: not reconnecting because internet is not reachable; sending an udp packet to try to activate network");
        [self sendUDPPacket:@"TRY_ACTIVATE"];
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
        if (message.deliveries.count == 1) {
            Delivery * delivery = message.deliveries.anyObject;
            if (delivery != nil && delivery.receiver != nil) {
                if (message.attachment != nil && (message.attachment.uploadURL == nil || message.attachment.uploadURL.length == 0)) {
                    // get attachment transfer url in case there are none yet
                    [self createUrlsForTransferOfAttachmentOfMessage:message];
                } else {
                    [self finishSendMessage:message toContact:message.contact withDelivery:message.deliveries.anyObject withAttachment:message.attachment];
                }
            } else {
                NSLog(@"removing message without receiver, tag = %@", message.messageTag);
                [self.delegate deleteObject:message];
            }
        } else {
            NSLog(@"removing message without bad number of deliveries=%d (must be 1), tag = %@", (int)message.deliveries.count,  message.messageTag);
            [self.delegate deleteObject:message];
        }
    }
}

- (void) flushIncomingDeliveriesInContext:(NSManagedObjectContext*)context {
    NSArray * deliveries = [self getPendingIncomingDeliveries:context];
    NSLog(@"flushIncomingDeliveriesInContext: found %d pending incoming deliveries", (int)deliveries.count);
    for (Delivery * delivery in deliveries) {
        if (delivery.message.isRead && delivery.isUnseen) {
            if (DELIVERY_TRACE) NSLog(@"flushIncomingDeliveriesInContext: confirming seen message %@", delivery.message.messageId);
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[delivery.message, delivery] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                [self inDeliveryConfirmMessage:managedObjects[0] withDelivery:managedObjects[1]];
            }];
        }
    }
}

- (NSArray*)getPendingIncomingDeliveries:(NSManagedObjectContext *)context{
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:[Delivery entityName] inManagedObjectContext: context];
    [fetchRequest setEntity:entity];
    //[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(state == '%@' OR state == '%@') AND message.isOutgoingFlag == NO",
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(state == 'deliveredUnseen' OR state == 'deliveredUnseenAcknowledged') AND message.isOutgoingFlag == NO AND message.isReadFlag == YES"]];
    
    NSError *error;
    NSArray *deliveries = [context executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"Fetch request for 'getPendingIncomingDeliveries' failed: %@", error);
        abort();
    }
    return deliveries;
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
        if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: other messages before (%@-%@) = %d",sinceTime,message.timeAccepted, (int)messagesBefore.count);}
    } else {
        // no other message before in interval, start new section
        message.timeSection = message.timeAccepted;
        if (SECTION_TRACE) {NSLog(@"adjustTimeSectionsForMessage: no other messages before in (%@-%@) count=%d, new section time%@", sinceTime,message.timeAccepted, (int)messagesBefore.count, message.timeAccepted);}
    }
    // we have now processed all message with a time <= message.timeAccepted
    // adjust time section of messages after this section
    NSDate * untilTime = [NSDate dateWithTimeInterval:sectionInterval sinceDate:message.timeAccepted];
    
    NSArray * messagesAfter = [self messagesByContact:message.contact inIntervalAfterTime:message.timeAccepted untilTime:untilTime];
    int count = (int)[messagesAfter count];
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
    
    NSString * clientId = relationshipDict[@"otherClientId"];
    if ([clientId isEqualToString: [UserProfile sharedProfile].clientId]) {
        return;
    }
    if (clientId == nil) {
        NSLog(@"ERROR: updateRelationship: missing clientId");
        return;
    }
    //[self.delegate performWithLockingId:clientId inNewBackgroundContext:^(NSManagedObjectContext *context) {
    [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        if (USE_VALIDATOR) [self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
        if (LOCKING_TRACE) NSLog(@"Entering synchronized updateRelationship %@",clientId);
        
        Contact * contact = nil;
        @synchronized([self insertionLock:clientId]) {
            contact = [self getContactByClientId: clientId inContext:context];
            
            // The server may send relationship updates with state 'none' even after depairing, so handle that
            if ([relationshipDict[@"state"] isEqualToString: @"none"]) {
                // if there is a local contact, check if we should delete, otherwise do nothing and return
                if (contact != nil) {
                    BOOL disinvitation = contact.isInvited || contact.invitedMe;
                    if (disinvitation) {
                        if (contact.groupMemberships.count > 0) {
                            contact.relationshipState = kRelationStateGroupFriend;
                        } else {
                            contact.relationshipState = kRelationStateInternalKept;
                        }
                    } else {
                        [self checkRelationsipStateForGroupMembershipOfContact:contact];
                        if (!contact.isNotRelated && !contact.isKept && !contact.isGroupFriend) {
                            contact.relationshipState = kRelationStateNone;
                            [self handleDeletionOfContact:contact withForce:NO inContext:context];
                        }
                    }
                }
                if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r1) %@",clientId);
                return;
            }
            
            // create new contact because we don't have this one yet
            if (contact == nil) {
                if (PRESENCE_DEBUG) NSLog(@"inserting new contact id %@",clientId);
                contact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:context];
                contact.type = [Contact entityName];
                contact.clientId = clientId;
                contact.nickName = kNickNewRelationship;
                contact.latestMessageTime = [self estimatedServerTime];
                [self.delegate saveContext:context];
            }
        }
        // show "new friend" or "blocked" message in case the state changed
        if ([self hasActualNickName: contact] && !contact.isFriend && [kRelationStateFriend isEqualToString: relationshipDict[@"state"] ]) {
            [self newFriendAlertForContact:contact];
        } else if (!contact.isBlocked && [kRelationStateBlocked isEqualToString: relationshipDict[@"state"]]) {
            [self blockedAlertForContact:contact];
        } else if (!contact.invitedMe && [kRelationStateInvitedMe isEqualToString: relationshipDict[@"state"]]) {
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[contact] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                Contact * contact = managedObjects[0];
                [self invitationAsFriendAlertByContact:contact];
            }];
        }
        
        // NSLog(@"relationship Dict: %@", relationshipDict);
        [contact updateWithDictionary: relationshipDict];
        
        [self checkRelationsipStateForGroupMembershipOfContact:contact];
        
        //[self.delegate saveContext:context];
        if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere %@",clientId);
    }];
}

// main context only
- (void) acceptFriendFailedAlertForContact:(Contact*)contact {
    [self.delegate assertMainContext];
    NSString * contactName = contact.nickName;
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_accept_friend_failed_message %@",nil), contactName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_accept_friend_failed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

// main context only
- (void) refuseFriendFailedAlertForContact:(Contact*)contact {
    [self.delegate assertMainContext];
    NSString * contactName = contact.nickName;
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_refuse_friend_failed_message %@",nil), contactName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_refuse_friend_failed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

// main context only
- (void) inviteFriendFailedAlertForContact:(Contact*)contact {
    [self.delegate assertMainContext];
    NSString * contactName = contact.nickName;
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_invite_friend_failed_message %@",nil), contactName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_invite_friend_failed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

// main context only
- (void) disinviteFriendFailedAlertForContact:(Contact*)contact {
    [self.delegate assertMainContext];
    NSString * contactName = contact.nickName;
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_disinvite_friend_failed_message %@",nil), contactName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_disinvite_friend_failed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

// main context only
- (void) inviteGroupMemberFailedForContact:(Contact*)contact inGroup:(Group*)group {
    [self.delegate assertMainContext];
    NSString * contactName = contact.nickName;
    NSString * groupName = group.nickName;
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_invite_failed_message %@ %@",nil), contactName, groupName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_invite_friend_failed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

// main context only
- (void) disinviteGroupMemberFailedForContact:(Contact*)contact inGroup:(Group*)group {
    [self.delegate assertMainContext];
    NSString * contactName = contact.nickName;
    NSString * groupName = group.nickName;
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_disinvite_failed_message %@ %@",nil), contactName, groupName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_disinvite_friend_failed_title", nil)
                                                     message: message
                                                    delegate:nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}


// main context only
- (void) invitationAsFriendAlertByContact:(Contact*)contact {
    [self.delegate assertMainContext];
    
    @synchronized(_contactPresentingFriendInvitation) {
        if ([_contactPresentingFriendInvitation containsObject:contact.clientId]) {
            return;
        }
    }
    [_contactPresentingFriendInvitation addObject:contact.clientId];

    
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_invited_me_as_friend_message %@",nil), contact.nickName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_invited_me_as_friend_title", nil)
                                                     message: NSLocalizedString(message, nil)
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 switch (buttonIndex) {
                                                     case 0: {
                                                         // accept invitation
                                                         [self acceptFriend:contact.clientId handler:^(BOOL ok) {
                                                             if (!ok) {
                                                                 [self acceptFriendFailedAlertForContact:contact];
                                                             }
                                                             @synchronized(_contactPresentingFriendInvitation) {
                                                                 if ([_contactPresentingFriendInvitation containsObject:contact.clientId]) {
                                                                     [_contactPresentingFriendInvitation removeObject:contact.clientId];
                                                                 }
                                                             }
                                                         }];
                                                        }
                                                        break;
                                                     case 1: {
                                                         // decline invitation
                                                         [self refuseFriend:contact.clientId handler:^(BOOL ok) {
                                                             if (!ok) {
                                                                 [self refuseFriendFailedAlertForContact:contact];
                                                             }
                                                             @synchronized(_contactPresentingFriendInvitation) {
                                                                 if ([_contactPresentingFriendInvitation containsObject:contact.clientId]) {
                                                                     [_contactPresentingFriendInvitation removeObject:contact.clientId];
                                                                 }
                                                             }
                                                         }];
                                                        }
                                                        break;
                                                     case 2:
                                                         // do nothing
                                                         @synchronized(_contactPresentingFriendInvitation) {
                                                             if ([_contactPresentingFriendInvitation containsObject:contact.clientId]) {
                                                                 [_contactPresentingFriendInvitation removeObject:contact.clientId];
                                                             }
                                                         }
                                                         break;
                                                 }
                                             }
                                           cancelButtonTitle: nil
                                           otherButtonTitles: NSLocalizedString(@"contact_invited_me_as_friend_accept_btn_title", nil), NSLocalizedString(@"contact_invited_me_as_friend_decline_btn_title", nil), NSLocalizedString(@"contact_invited_me_as_friend_decide_later_btn_title", nil),nil];
    [alert show];
}


// background context safe
- (void) newFriendAlertForContact:(Contact*)contact {
    @synchronized(_contactPresentingFriendMessage) {
        if ([_contactPresentingFriendMessage containsObject:contact.clientId]) {
            return;
        }
    }
    [_contactPresentingFriendMessage addObject:contact.clientId];

    NSString * contactName = contact.nickName;
    [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_new_friend_message",nil), contactName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_new_friend_title", nil)
                                                         message: message
                                                 completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                     @synchronized(_contactPresentingFriendMessage) {
                                                         if ([_contactPresentingFriendMessage containsObject:contact.clientId]) {
                                                             [_contactPresentingFriendMessage removeObject:contact.clientId];
                                                         }
                                                     }
                                                 }
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

// background context safe
- (void) blockedAlertForContact:(Contact*)contact {
    NSString * contactName = contact.nickName;
    [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_blocked_message",nil), contactName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_blocked_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

// background context safe
- (void) removedAlertForContact:(Contact*)contact {
    NSString * contactName = contact.nickName;
    [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_relationship_removed_message",nil), contactName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_relationship_removed_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

// background context safe
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

// background context safe
- (void) removedButKeptInGroupAlertForContact:(Contact*)contact {
    NSString * contactName = contact.nickName;
    NSString * membershipList = [self groupMembershipListofContact:contact];
    
    [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
        
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_kept_and_relationship_removed_message",nil), contactName, membershipList];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_relationship_removed_title", nil)
                                                         message: message
                                                        delegate:nil
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }];
}

// returns true if objectToDelete object can be deleted, either because it is not inspected or could be unwinded
- (BOOL)ensureUnwindView:(id)objectToDelete {
    
    if ([self.delegate isInspecting:objectToDelete]) {
        // unwind e.g. a chat view if we have the deleted contact's chat open
        id inspector = [self.delegate inspectorOf:objectToDelete];
        if ([inspector respondsToSelector: @selector(unwindToRootController)]) {
            UIViewController * unwinder = [inspector performSelector:@selector(unwindToRootController)];
            NSLog(@"ensureUnwindView: unwindToRoot, inspector=%@, unwinder=%@", inspector, unwinder);
            if ([self.delegate.currentObjectContext isEqual:self.delegate.mainObjectContext]) {
                [unwinder performSegueWithIdentifier: @"unwindToRoot" sender:self];
            } else {
                [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
                    [unwinder performSegueWithIdentifier: @"unwindToRoot" sender:self];
                }];
            }
            return YES;
        } else {
            NSLog(@"ensureUnwindView: can not unwind inspector");
            return NO;
        }
    }
    NSLog(@"ensureUnwindView: ok,  objectToDelete is not being inspected");
    return YES;
}

// background context safe
- (void) askForDeletionOfContact:(Contact*)contact {
    
    // save current context in case it is a background context in order to make sure we have a final object id, then obtain it
    [self.delegate saveContext:self.delegate.currentObjectContext];
    NSManagedObjectID * contactId = contact.objectID;
    
    [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
        Contact* contact = (Contact*)[context objectWithID:contactId];
        NSString * message = [NSString stringWithFormat: NSLocalizedString(@"contact_delete_associated_data_question",nil), contact.nickName];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"contact_deleted_title", nil)
                                                         message: message
                                                 completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                     switch (buttonIndex) {
                                                         case 1: // delete a group member contacts that is not friend or contact in other group
                                                             if ([self ensureUnwindView:contact]) {
                                                                 [self.delegate deleteObject:contact inContext:context];
                                                             } else {
                                                                 NSLog(@"#WARNING: could not unwind inspector of contact, autokeeping");
                                                                 contact.relationshipState = kRelationStateInternalKept;
                                                             }
                                                            break;
                                                         case 0:
                                                             // keep contact and chats
                                                             contact.relationshipState = kRelationStateInternalKept;
                                                             break;
                                                     }
                                                     [self.delegate saveContext:context];
                                                 }
                                               cancelButtonTitle: NSLocalizedString(@"contact_keep_data_button", nil)
                                               otherButtonTitles: NSLocalizedString(@"contact_delete_data_button",nil),nil];
        [alert show];
    }];
}

// background context safe
- (void) handleDeletionOfContact:(Contact*)contact withForce:(BOOL)force inContext:(NSManagedObjectContext*) context {
    
    // autokeep contacts that are currently inspected
    if (!force && (AppDelegate.instance.environmentMode != ACTIVATION_MODE_NONE && (contact.isNearby || contact.isWorldwide))) {
        if (DEBUG_DELETION) NSLog(@"handleDeletionOfContact: is active nearby or being inspected, autokeeping contact id %@",contact.clientId);
        if (contact.groupMemberships.count == 0) {
            contact.relationshipState = kRelationStateInternalKept;
        } else {
            contact.relationshipState = kRelationStateGroupFriend;
        }
        return;
    }
    
    // delete right away if there is nothing to save
    if (force || (contact.messages.count == 0 && contact.groupMemberships.count == 0 && contact.deliveriesSent.count == 0)) {
        // if there is nothing to save, delete right away and dont ask
        if (RELATIONSHIP_DEBUG || DEBUG_DELETION) NSLog(@"handleDeletionOfContact: nothing to save or kept, delete contact id %@",contact.clientId);
        if ([self ensureUnwindView:contact]) {
            if (!force) {
                [self removedAlertForContact:contact];
            }
            [AppDelegate.instance deleteObject:contact inContext:context];
        } else {
            NSLog(@"#WARNING: could not unwind inspector of contact, autokeeping");
            contact.relationshipState = kRelationStateInternalKept;
        }
        [AppDelegate.instance saveContext:context];
        return;
    }
    
    // there was something to save, so ask
    if (contact.groupMemberships.count == 0) {
        // no group membership, but there are messages associated with this contact
        if (DEBUG_DELETION) NSLog(@"handleDeletionOfContact: no group membership, but there are messages associated with contact id %@",contact.clientId);
        [self askForDeletionOfContact:contact];
    } else {
        if (DEBUG_DELETION) NSLog(@"handleDeletionOfContact: group membership(s) found for contact id %@",contact.clientId);
        // there is an active group membership for this contact, so keep it
        if (!contact.isGroupFriend) {
            contact.relationshipState = kRelationStateGroupFriend;
            [self removedButKeptInGroupAlertForContact:contact];
            if (DEBUG_DELETION) NSLog(@"handleDeletionOfContact: marking contact id %@ as group friend, ",contact.clientId);
        }
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
        //[self.delegate performWithLockingId:@"presences" inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            for (id presence in changedPresences) {
                // NSLog(@"updatePresences presence=%@",presence);
                [self presenceUpdated:presence inContext:context];
                //[self presenceUpdatedLocked:presence inContext:context];
            }
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self checkContactsWithCompletion:completion];
            }];
        }];
    }];
}


- (void) fetchKeyForContact:(Contact *)theContact withKeyId:(NSString*) theId withCompletion:(CompletionBlock)handler {
    
    [self getKeyForClientId: theContact.clientId withKeyId:theId keyHandler:^(NSDictionary * keyRecord) {
        if (theContact.clientId == nil) {
            NSLog(@"ERROR: fetchKeyForContact: nil contact or clientId");
            return;
        }
        if (keyRecord == nil) {
            // retry
            // [self fetchKeyForContact:theContact withKeyId:theId withCompletion:handler];
            NSLog(@"ERROR: could not fetch key with keyid %@ for contact id %@ nick %@", theId, theContact.clientId, theContact.nickName);
            NSString * myDescription = [NSString stringWithFormat:@"ERROR: key not fetch key with keyid %@ for contact: %@ nick %@", theId, theContact.clientId, theContact.nickName];
            NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9913 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            if (handler != nil) {
                handler(myError);
            }
            return;
        }
        
        NSManagedObjectID * contactObjId = theContact.objectID;
        //[self.delegate performWithLockingId:theContact.clientId inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            if (USE_VALIDATOR) [self validateObject: keyRecord forEntity:@"RPC_TalkKey_in"];  // TODO: Handle Validation Error
            Contact * theContact = (Contact *)[context objectWithID:contactObjId];
            if (theContact != nil) {
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
                    //[self.delegate saveDatabase];
                    if (handler != nil) {
                        [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                            handler(nil);
                        }];
                    }
                } else {
                    NSLog(@"ERROR: key not updated, response keyid mismatch for contact id %@ nick %@", theContact.clientId, theContact.nickName);
                    NSString * myDescription = [NSString stringWithFormat:@"ERROR: key not updated, response keyid mismatch for contact: %@ nick %@", theContact.clientId, theContact.nickName];
                    NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.backend" code: 9912 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                    if (handler != nil) {
                        [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                            handler(myError);
                        }];
                    }
                }
            } else {
                NSLog(@"#ERROR:fetchKeyForContact: nil contact");
            }
        }];
    }];
}

- (void) presenceUpdatedInBackground:(NSDictionary *) thePresence {
    NSString * myClient = thePresence[@"clientId"];
    if (myClient != nil) {
        //[self.delegate performWithLockingId:myClient inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self presenceUpdated:thePresence inContext:context];
        }];
    }
}

- (BOOL) hasActualNickName: (Contact*) contact {
    return contact.nickName != nil && [@[kNickNewMember, kNickNewPresence, kNickNewRelationship, kNickTemporary] indexOfObject: contact.nickName] == NSNotFound;
}

- (void) presenceUpdated:(NSDictionary *) thePresence inContext:(NSManagedObjectContext *)context {
    
    NSString * myClient = thePresence[@"clientId"];
    if ([myClient isEqualToString: [UserProfile sharedProfile].clientId]) {
        NSLog(@"WARNING: self presence update received (clientId: %@)", myClient);
        return;
    }
    if (PRESENCE_DEBUG) NSLog(@"Entered presenceUpdated %@",myClient);
    
    if (USE_VALIDATOR) [self validateObject: thePresence forEntity:@"RPC_TalkPresence_in"];  // TODO: Handle Validation Error
    
    BOOL newContact = NO;
    Contact * myContact = nil;
    @synchronized([self insertionLock:myClient]) {
        myContact = [self getContactByClientId:myClient inContext:context];
        if (myContact == nil) {
            if (PRESENCE_DEBUG) NSLog(@"presenceUpdated: clientId unknown, creating new contact for client: %@", myClient);
            myContact = [NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext: context];
            myContact.type = [Contact entityName];
            myContact.clientId = myClient;
            myContact.relationshipState = kRelationStateNone;
            myContact.relationshipLastChanged = [NSDate dateWithTimeIntervalSince1970:0];
            myContact.avatarURL = @"";
            myContact.nickName = kNickNewPresence;
            myContact.latestMessageTime = [self estimatedServerTime];
            [self checkRelationsipStateForGroupMembershipOfContact:myContact];
            newContact = YES;
            [self.delegate saveContext:context];
        } else {
            if (PRESENCE_DEBUG) NSLog(@"found contact for clientId %@, nick %@", myClient, myContact.nickName);
        }
        myContact.lastUpdateReceived = [NSDate date];
    }
    
    BOOL newFriend = NO;
    
    if (myContact) {
        NSString * newNickName = thePresence[@"clientName"];
        if ( ! [self hasActualNickName: myContact] && newNickName.length > 0 && myContact.isFriend) {
            newFriend = YES;
        }
        myContact.nickName = newNickName;
        myContact.status = thePresence[@"clientStatus"];
        myContact.connectionStatus = thePresence[@"connectionStatus"];

        if (PRESENCE_DEBUG) NSLog(@"presenceUpdated: updated contact clientId %@, with nick %@ connectionStatus %@ status %@", myClient, myContact.nickName, myContact.connectionStatus, myContact.status);
        
        if (![myContact.publicKeyId isEqualToString: thePresence[@"keyId"]] || ((self.firstConnectionAfterCrashOrUpdate  || _uncleanConnectionShutdown) || [self fullSync])) {
            // fetch key
            NSString * keyId = thePresence[@"keyId"];
            if (PRESENCE_DEBUG) NSLog(@"presenceUpdated: scheduling key fetch for contact id %@ tag %@, keyId %@",myClient, myContact.nickName, keyId);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                Contact * contact = [self getContactByClientId:myClient inContext:context];
                if (contact != nil) {
                    [self fetchKeyForContact: contact withKeyId:keyId withCompletion:^(NSError *theError) {
                    }];
                }
            }];
        }
        NSString * avatarUrl = thePresence[@"avatarUrl"];
        if (PRESENCE_DEBUG) NSLog(@"presenceUpdated: scheduling avatar update for contact id %@ tag %@, avatarUrl %@",myClient, myContact.nickName, avatarUrl);
        [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
            Contact * contact = [self getContactByClientId:myClient inContext:context];
            if (contact != nil) {
                [self updateAvatarForContact:contact forAvatarURL:avatarUrl];
            }
        }];
        
        myContact.presenceLastUpdatedMillis = thePresence[@"timestamp"];
        // NSLog(@"presenceUpdated, contact = %@", myContact);
        if (newContact) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                Contact * contact = [self getContactByClientId:myClient inContext:context];
                if (contact != nil) {
                    [self checkIfNeedToPresentInvitationForGroupAfterNewPresenceOf:contact];
                }
            }];
        }
    } else {
        NSLog(@"#ERROR: presenceUpdated: unknown clientId and failed to create new contact for id: %@", myClient);
        return;
    }
    if (newFriend) {
        if (PRESENCE_DEBUG) NSLog(@"presenceUpdated: newFriendAlert for contact id %@ tag %@",myClient, myContact.nickName);
        [self.delegate saveContext:context];
        [self newFriendAlertForContact:myContact];
    }
    if (PRESENCE_DEBUG) NSLog(@"presenceUpdated: done for contact id %@ tag %@",myClient, myContact.nickName);
}

- (void) presenceModifiedInBackground:(NSDictionary *) thePresence {
    NSString * myClient = thePresence[@"clientId"];
    if (myClient != nil) {
        //[self.delegate performWithLockingId:myClient inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self presenceModified:thePresence inContext:context];
        }];
    }
}

- (void) presenceModified:(NSDictionary *) thePresence inContext:(NSManagedObjectContext*) context {
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
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[myContact] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                [self fetchKeyForContact: managedObjects[0] withKeyId:newKeyId withCompletion:^(NSError *theError) {
                }];
            }];
        }
    }
    
    NSString * newAvatarURL = thePresence[@"avatarUrl"];
    if (newAvatarURL != nil) {
        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[myContact] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
            [self updateAvatarForContact:managedObjects[0] forAvatarURL:newAvatarURL];
        }];
    }
    
    NSNumber * newTimeStamp = thePresence[@"timestamp"];
    if (newTimeStamp != nil) {
        NSLog(@"WARNING: presenceModified receiced timestamp for contact id = %@", myContact.clientId);
        myContact.presenceLastUpdatedMillis = newTimeStamp;
        
    }
    //[self.delegate saveDatabase];
}

- (void) updateAvatarForContact:(Contact*)myContact forAvatarURL:(NSString*)theAvatarURL {
    if (![myContact.avatarURL isEqualToString: theAvatarURL]) {
        if (theAvatarURL.length) {
            if (CONNECTION_TRACE) {NSLog(@"updateAvatarForContact, downloading avatar from URL %@", theAvatarURL);}
            
            NSString * contactId = myContact.clientId;
            [HXOBackend downloadDataFromURL:theAvatarURL inQueue:_avatarDownloadQueue withCompletion:^(NSData * data, NSError * error) {
                NSData * myNewAvatar = data;
                if (myNewAvatar != nil && error == nil) {
                    // NSLog(@"presenceUpdated, avatar downloaded");
                    // search for contact again in case it has been deleted
                    Contact * myContact = [self getContactByClientId:contactId inContext:self.delegate.currentObjectContext];
                    if (myContact != nil) {
                        myContact.avatar = myNewAvatar;
                        myContact.avatarURL = theAvatarURL;
                    }
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

//  void settingsChanged(String setting, String value, String message);
- (void) settingsChanged:(NSArray*) param {
    for (int i = 0; i < 3; i+=3) {
        NSString * setting = param[i];
        id value = param[i+1];
        id currentValue = [[HXOUserDefaults standardUserDefaults] valueForKey:setting];
        if (currentValue != nil) {
            if (![currentValue isEqual:value]) {
                [[HXOUserDefaults standardUserDefaults] setValue:value forKey: setting];
                [[HXOUserDefaults standardUserDefaults] synchronize];
                NSLog(@"#INFO: Setting %@ = %@ has been set to %@", setting, currentValue, [[HXOUserDefaults standardUserDefaults] valueForKey:setting]);
                NSString * title = param[i+2];
                if (title != nil && title.length>0) {
                    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                                     message: nil
                                                                    delegate: nil
                                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                           otherButtonTitles: nil];
                    [alert show];
                }
            } else {
                NSLog(@"#INFO: Setting %@ = %@ is already %@", setting, currentValue, value);
            }
            //NSLog(@"#INFO: bool value is %d", [[HXOUserDefaults standardUserDefaults] boolForKey:setting]);
        } else {
            NSLog(@"#ERROR: Setting %@ does not exist", setting);
        }
    }
}

#pragma mark - Group related rpc interfaces: notifications

//  void groupUpdated(TalkGroup group);
- (void) groupUpdated:(NSArray*) group_param {
    NSString * groupId = group_param[0][@"groupId"];
    if (groupId != nil) {
        //[self.delegate performWithLockingId:groupId inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self updateGroupHere: group_param[0] inContext:context];
        }];
    } else {
        NSLog(@"'ERROR: groupUpdated: nil group id");
    }
}

// void groupMemberUpdated(TalkGroupMember groupMember);
- (void) groupMemberUpdated:(NSArray*) groupMember_param {
    NSString * groupId = groupMember_param[0][@"groupId"];
    if (groupId != nil) {
        //[self.delegate performWithLockingId:groupId inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self updateGroupMemberHere: groupMember_param[0] inContext:context];
        }];
    } else {
        NSLog(@"'ERROR: groupMemberUpdated: nil group id");
    }
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
    group.latestMessageTime = [self estimatedServerTime];
    //group.groupKey = [Crypto random256BitKey];
    
    GroupMembership * myMember = (GroupMembership*)[NSEntityDescription insertNewObjectForEntityForName: [GroupMembership entityName] inManagedObjectContext:self.delegate.mainObjectContext];
    myMember.group = group;
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


// public TalkGroup createGroupWithMembers(String groupTag, String groupName, String[] members, String[] roles) {
- (void) createGroupWithMembersAndType:(NSString*)type withTag:(NSString*)groupTag withName:(NSString*)groupName withMembers:(NSArray*)memberIds withRoles:(NSArray*)roles withHandler:(CreateGroupHandler)handler {
    
    [_serverConnection invoke: @"createGroupWithMembers" withParams: @[type, groupTag, groupName, memberIds, roles]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSString * groupId = responseOrError[@"groupId"];
             if (groupId != nil) {
                 //[self.delegate performWithLockingId:groupId inNewBackgroundContext:^(NSManagedObjectContext *context) {
                 [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
                     [self updateGroupHere: responseOrError inContext:context];
                     [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                         Group * group = [self getGroupById:groupId inContext:context];
                         if (handler) handler(group);
                     }];
                 }];
             } else {
                 NSLog(@"'ERROR: createGroupWithMembers: nil group id");
             }
         } else {
             NSLog(@"createGroupWithMembers() failed: %@", responseOrError);
             if (handler) handler(nil);
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
             if (_firstEnvironmentUpdateHandler != nil) _firstEnvironmentUpdateHandler(YES);
             if (GROUP_DEBUG) NSLog(@"updateEnvironment() returned groupId: %@", responseOrError);
         } else {
             NSLog(@"updateEnvironment() failed: %@", responseOrError);
             handler(nil);
             if (_firstEnvironmentUpdateHandler != nil) _firstEnvironmentUpdateHandler(NO);
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

// void releaseEnvironment(String type);
- (void) releaseEnvironmentType:(NSString*)type withHandler:(GenericResultHandler)handler {
    
    [_serverConnection invoke: @"releaseEnvironment" withParams: @[type]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             handler(YES);
             if (GROUP_DEBUG) NSLog(@"releaseEnvironment() returned success");
         } else {
             NSLog(@"releaseEnvironment() failed: %@", responseOrError);
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

-(void)disableFullSync {
    [[HXOUserDefaults standardUserDefaults] setBool: NO forKey: @"fullSync"];
}

-(BOOL)quickStart {
    return [[[HXOUserDefaults standardUserDefaults] objectForKey:@"quickStart"] boolValue];
}

- (void) syncGroupsWithForce:(BOOL)forceAll withCompletion:(GenericResultHandler)completion {
    NSDate * latestChange;
    if (forceAll) {
        latestChange = [NSDate dateWithTimeIntervalSince1970:0];
    } else {
        latestChange = [self getLatestChangeDateForGroups];
    }
    
    [self getGroups: latestChange groupsHandler:^(NSArray * changedGroupsDicts) {
        //[self.delegate performWithLockingId:@"groups" inNewBackgroundContext:^(NSManagedObjectContext *context) {
        [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
            if (GROUP_DEBUG) NSLog(@"getGroups result = %@",changedGroupsDicts);
            if ([changedGroupsDicts isKindOfClass:[NSArray class]]) {
                BOOL ok = YES;
                for (NSDictionary * groupDict in changedGroupsDicts) {
                    
                    BOOL stateOk = [self updateGroupHere:groupDict inContext:context];
                    Group * group = [self getGroupById:groupDict[@"groupId"] inContext:context];
                    if (group != nil) {
                        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)  {
                            Group * group = managedObjects[0];
                            [self makeSureAvatarUploadedForGroup:group withCompletion:^(NSError *theError) {
                                if (CHECK_URL_TRACE) NSLog(@"makeSureAvatarUploadedForGroup %@ error=%@",group.nickName,theError);
                            }];
                            if (forceAll) {
                                [self getGroupMembers:group lastKnown:[NSDate dateWithTimeIntervalSince1970:0] withCompletion:nil];
                            } else {
                                [self getGroupMembers:group lastKnown:[group latestMemberChangeDate] withCompletion:nil];
                            }
                        }];
                    }
                    ok = ok && stateOk;
                }
            }
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context)  {
                [self checkGroupMembershipsWithCompletion:completion];
            }];
        }];
    }];
    if (!forceAll) {
        NSArray * groupArray = [self getActiveGroupsInContext:self.delegate.mainObjectContext];
        for (Group * group in groupArray) {
            [self getGroupMembers:group lastKnown:[group latestMemberChangeDate] withCompletion:nil];
        }
    }
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

#if 0
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
    if (SINGLE_NEARBY_DEBUG) NSLog(@"singleNearbyGroupWithId: %@", groupId);
    NSArray * groups = [self getNearbyGroupsInContext:context];
    if (SINGLE_NEARBY_DEBUG) NSLog(@"singleNearbyGroupWithId: %@, found %d nearby groups", groupId, (int)groups.count);
    if (groups.count > 0) {
        Group * inspectedGroup = [self findInspectedNearbyGroupInContext:context];
        if (inspectedGroup == nil) {
            inspectedGroup = groups[0];
        }
        if (SINGLE_NEARBY_DEBUG) NSLog(@"singleNearbyGroupWithId: changing group %@ to %@", inspectedGroup.clientId, groupId);
        [inspectedGroup changeIdTo:groupId];
        
        if (groups.count > 1) {
            [self mergeGroups: groups intoGroup:inspectedGroup inContext:context];
        }
        return inspectedGroup;
    }
    return nil;
}
#else

-(NSArray*) getSpecialGroupsWithType:(NSString*)type inContext:(NSManagedObjectContext *)context{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Group" inManagedObjectContext: context];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"type == 'Group' AND groupType == %@",type ]];
    
    NSError *error;
    NSArray *groups = [context executeFetchRequest:fetchRequest error:&error];
    if (groups == nil)
    {
        NSLog(@"Fetch request for 'getSpecialGroupsWithType %@' failed: %@",type, error);
        abort();
    }
    return groups;
}

-(Group*)findInspectedSpecialGroupWithType:(NSString*)type inContext:(NSManagedObjectContext *)context {
    NSArray * groups = [self getSpecialGroupsWithType:type inContext:context];
    for (Group * group in groups) {
        if ([self.delegate isInspecting:group]) {
            return group;
        }
    }
    return nil;
}

-(Group*)singleSpecialGroupWithType:(NSString*)type withId:(NSString*)groupId inContext:(NSManagedObjectContext *)context {
    if (SINGLE_NEARBY_DEBUG) NSLog(@"singleSpecialGroupWithType: %@ withId %@", type, groupId);
    NSArray * groups = [self getSpecialGroupsWithType:type inContext:context];
    if (SINGLE_NEARBY_DEBUG) NSLog(@"singleSpecialGroupWithType: %@, found %d %@ groups", groupId, (int)groups.count,type);
    if (groups.count > 0) {
        Group * inspectedGroup = [self findInspectedSpecialGroupWithType:type inContext:context];
        if (inspectedGroup == nil) {
            inspectedGroup = groups[0];
        }
        if (SINGLE_NEARBY_DEBUG) NSLog(@"singleSpecialGroupWithType %@: changing group %@ to %@", type, inspectedGroup.clientId, groupId);
        [inspectedGroup changeIdTo:groupId];
        
        if (groups.count > 1) {
            [self mergeGroups: groups intoGroup:inspectedGroup inContext:context];
        }
        return inspectedGroup;
    }
    return nil;
}

#endif

- (BOOL) updateGroupHere: (NSDictionary*) groupDict inContext:(NSManagedObjectContext*) context {
    //[self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
    if (GROUP_DEBUG) NSLog(@"updateGroupHere with %@",groupDict);
    
    NSString * groupId = groupDict[@"groupId"];
    NSString * groupTag = groupDict[@"groupTag"];
    if (LOCKING_TRACE) NSLog(@"Entering updateGroupHere %@",groupId);
    
    if (groupId == nil || groupTag == nil) {
        NSLog(@"#ERROR: group without tag or id");
        return NO;
    }
    
    Group * group = [self getGroupById: groupId orByTag:groupTag inContext:context];
    
    NSString * groupState = groupDict[@"state"];
    if (groupState == nil) {
        NSLog(@"Error: group without group state, dict=%@", groupDict);
        return NO;
    }
    if (group != nil) {
        group.lastUpdateReceived = [NSDate date];
    }
    
    if ([kGroupStateNone isEqualToString: groupState]) {
        if (group != nil && !group.isKeptGroup && !group.isRemovedGroup && !group.isNearbyGroup && !group.isWorldwideGroup) {
            if (GROUP_DEBUG) NSLog(@"updateGroupHere: handleDeletionOfGroup %@", group.clientId);
            [group updateWithDictionary: groupDict];
            [self handleDeletionOfGroup:group inContext:context];
            if (GROUP_DEBUG) NSLog(@"updateGroupHere: end processing of a removed group");
        }
        return YES;
    }
    
    if (group == nil) {
        // handle nearby and worldwide group merging
        if ([kGroupTypeNearby isEqualToString: groupDict[@"groupType"]]) {
            group = [self singleSpecialGroupWithType:kGroupTypeNearby withId:groupId inContext:context];
        } else if ([kGroupTypeWorldwide isEqualToString: groupDict[@"groupType"]]) {
            group = [self singleSpecialGroupWithType:kGroupTypeWorldwide withId:groupId inContext:context];
        }
        if (group == nil) {
            group = (Group*)[NSEntityDescription insertNewObjectForEntityForName: [Group entityName] inManagedObjectContext:context];
            group.type = [Group entityName];
            group.clientId = groupId;
            group.lastUpdateReceived = [NSDate date];
            group.latestMessageTime = [self estimatedServerTime];
            if (GROUP_DEBUG) NSLog(@"updateGroupHere: created a new group with id %@",groupId);
        }
    }
    
    BOOL tryPresentInvitation = NO;
    // _groupsNotYetPresentedInvitation will only contain the group if our own group contact has already arrived
    if ([_groupsNotYetPresentedInvitation containsObject:group.clientId] && [kGroupStateExists isEqualToString:groupState]) {
        tryPresentInvitation = YES;
    }
    
    [group updateWithDictionary: groupDict];
    
    if (!group.isKeptGroup && group.isKeptRelation) {
        group.relationshipState = nil;
    }
    
    // download group avatar if changed
    if (!group.iAmAdmin && groupDict[@"groupAvatarUrl"] != group.avatarURL) {
        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
            [self updateAvatarForContact:managedObjects[0] forAvatarURL:groupDict[@"groupAvatarUrl"]];
        }];
    }
    
    //[self.delegate saveContext:context];
    
    if (tryPresentInvitation) {
        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
            Group * group = (Group*)managedObjects[0];
            [self tryPresentInvitationIfPossibleForGroup:group withMemberShip:group.myGroupMembership];
        }];
    }
    if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupHere %@",groupId);
    return YES;
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
            if (handler != nil) handler(responseOrError);
        } else {
            NSLog(@"getGroupMembers(): failed: %@", responseOrError);
            if (handler != nil) handler(nil);
        }
    }];
}

- (void) getGroupMembers:(Group *)group lastKnown:(NSDate *)lastKnown
          withCompletion:(DoneBlock)completion
{
    [self getGroupMembers: group lastKnown:lastKnown membershipsHandler:^(NSArray * changedMembers) {
        if (changedMembers != nil) {
            //[self.delegate performWithLockingId:group.clientId inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
                for (NSDictionary * memberDict in changedMembers) {
                    [self updateGroupMemberHere: memberDict inContext:context];
                }
                if (completion) {
                    [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                        completion();
                    }];
                }
            }];
        } else {
            if (completion) completion();
        }
    }];
}

- (NSArray*)getActiveGroupsInContext:(NSManagedObjectContext*)context {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Group" inManagedObjectContext: context];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"type == 'Group' AND groupState != 'kept'" ]];
    
    NSError *error;
    NSArray *groupArray = [context executeFetchRequest:fetchRequest error:&error];
    if (groupArray == nil)
    {
        NSLog(@"Fetch request for 'Group' failed: %@", error);
        abort();
    }
    return groupArray;
}

// Boolean[] isMemberInGroups(String[] groupIds);
- (void) checkGroupMembershipsWithCompletion:(GenericResultHandler)completion {
    [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        NSArray * groupArray = [self getActiveGroupsInContext:context];
        
        NSMutableArray * groupsToCheck = [[NSMutableArray alloc]init];
        for (Group * group in groupArray) {
            [groupsToCheck addObject:group.clientId];
        }
        if (groupsToCheck.count > 0) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *mainContext) {
                [_serverConnection invoke: @"isMemberInGroups" withParams: @[groupsToCheck] onResponse: ^(id responseOrError, BOOL success) {
                    //[self.delegate performWithLockingId:@"groups" inNewBackgroundContext:^(NSManagedObjectContext *context) {
                    [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
                        if (success) {
                            NSArray * memberFlags = responseOrError;
                            if (memberFlags.count != groupsToCheck.count) {
                                NSLog(@"ERROR: isMemberInGroups(): return type mismatch, requested %d/%d flags, got %d", (int)groupsToCheck.count, (int)groupArray.count, (int)memberFlags.count);
                                return;
                            }
                            for (int i = 0; i < memberFlags.count;++i) {
                                if ([memberFlags[i] boolValue] == NO) {
                                    Group * group = [self getGroupById:groupsToCheck[i] inContext:context];
                                    if (group != nil && !group.isKept) {
                                        NSLog(@"checkGroupMemberships: removing group with id: %@ nick: %@", group.clientId, group.nickName);
                                        [self handleDeletionOfGroup:group inContext:context];
                                    } else {
                                        NSLog(@"checkGroupMemberships: can not remove group with id: %@", groupsToCheck[i]);
                                    }
                                }
                            }
                        } else {
                            NSLog(@"isMemberInGroups(): failed: %@", responseOrError);
                        }
                        if (completion) {
                            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                                completion(success);
                            }];
                        }
                    }];
                }];
            }];
        } else {
            if (completion) {
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    completion(YES);
                }];
            }
        }
    }];
}


// Boolean[] isContactOf  (String[] clientIds);
- (void) checkContactsWithCompletion:(GenericResultHandler)completion
{
    [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
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
            // NSLog(@"adding contact id %@ nick %@ type %@ relstate %@", contact.clientId, contact.nickName, contact.type, contact.relationshipState);
        }
        if (contactsToCheck.count > 0) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *mainContext) {
                [_serverConnection invoke: @"isContactOf" withParams: @[contactsToCheck] onResponse: ^(id responseOrError, BOOL success) {
                    //[self.delegate performWithLockingId:@"contacts" inNewBackgroundContext:^(NSManagedObjectContext *context) {
                    [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
                        if (success) {
                            NSArray * contactFlags = responseOrError;
                            if (contactFlags.count != contactsToCheck.count || contactFlags.count != contactArray.count) {
                                NSLog(@"ERROR: isContactOf(): return type mismatch, requested %d/%d flags, got %d", (int)contactsToCheck.count, (int)contactArray.count, (int)contactFlags.count);
                                return;
                            }
                            for (int i = 0; i < contactFlags.count;++i) {
                                if ([contactFlags[i] boolValue] == NO) {
                                    Contact * contact = [self getContactByClientId:contactsToCheck[i] inContext:context];
                                    if (contact != nil && !contact.isKept) {
                                        NSLog(@"checkContacts: removing contact with id: %@ nick: %@", contact.clientId, contact.nickName);
                                        [self handleDeletionOfContact:contact withForce:NO inContext:context];
                                    }
                                }
                            }
                        } else {
                            NSLog(@"isContactOf(): failed: %@", responseOrError);
                        }
                        if (completion) {
                            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                                completion(success);
                            }];
                        }
                    }];
                }];
            }];
        } else {
            if (completion) {
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    completion(YES);
                }];
            }
        }
    }];
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
            [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
                //[self updateGroupHereLocking:groupDict inContext:context];
                [self updateGroupHere:groupDict inContext:context];
            }];
        }
    }];
}

//TalkGroupMember getGroupMember(String groupId, Date lastKnown);
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
    NSString * groupId = member.group.clientId;
    [self getGroupMember:groupId clientId:member.contactClientId onResult:^(NSDictionary *memberDict) {
        if (memberDict != nil) {
            //[self.delegate performWithLockingId:groupId inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
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
    group.nickName = kNickTemporary;
    group.latestMessageTime = [self estimatedServerTime];
    if (GROUP_DEBUG) NSLog(@"createLocalGroup: created a new group with id %@",groupId);
    return group;
}

- (void) updateGroupMemberHere: (NSDictionary*) groupMemberDict inContext:(NSManagedObjectContext*)context{
    //[self validateObject: relationshipDict forEntity:@"RPC_TalkRelationship"];  // TODO: Handle Validation Error
    
    NSString * groupId = groupMemberDict[@"groupId"];
    if (LOCKING_TRACE) NSLog(@"Entering unsynchronized updateGroupMemberHere %@",groupId);
    Group * group = [self getGroupById: groupId inContext:context];
    if (group == nil) {
        if ([groupMemberDict[@"state"] isEqualToString:@"none"] || [groupMemberDict[@"state"] isEqualToString:@"groupRemoved"]) {
            if (LOCKING_TRACE) NSLog(@"Done synchronized updateGroupMemberHere (r1) %@",groupId);
            return;
        } else {
            if ([kGroupMembershipRoleNearbyMember isEqualToString: groupMemberDict[@"role"]]) {
                group = [self singleSpecialGroupWithType:kGroupTypeNearby withId:groupId inContext:context];
            } else  if ([kGroupMembershipRoleWorldwideMember isEqualToString: groupMemberDict[@"role"]]) {
                group = [self singleSpecialGroupWithType:kGroupTypeWorldwide withId:groupId inContext:context];
            }
            if (group == nil) {
                group = [self createLocalGroup:groupMemberDict[@"groupId"] withState:@"incomplete" inContext:context];
            }
        }
    }
    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere with %@",groupMemberDict);
    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere found group nick %@ id %@",group.nickName, group.clientId);
    
    NSString * memberClientId = groupMemberDict[@"clientId"];

    Contact * memberContact = nil;

    // When eventually creeating a new contact, make sure some other thread is not doing it at the same time
    @synchronized([self insertionLock:memberClientId]) {
        memberContact = [self getContactByClientId:memberClientId inContext:context];
        
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere getContactByClientId %@ returned group contact nick %@ id %@",memberClientId,memberContact.nickName,memberContact.clientId);
        if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere own clientId is %@",[UserProfile sharedProfile].clientId);
        
        if (memberContact == nil && ![[UserProfile sharedProfile].clientId isEqualToString:memberClientId]) {
            // There is no contact for this clientId, and it is not us
            if ([groupMemberDict[@"state"] isEqualToString:@"none"] || [groupMemberDict[@"state"] isEqualToString:@"groupRemoved"]) {
                // do not process unknown contacts with membership state ‘none'
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere not processing group member with state %@ id %@",groupMemberDict[@"state"], memberClientId);
                if (LOCKING_TRACE) NSLog(@"Done updateGroupMemberHere (r2) %@",groupId);
                return;
            }
            // create new Contact because it does not exist and is not own contact
            if (GROUP_DEBUG || PRESENCE_DEBUG) NSLog(@"updateGroupMemberHere: contact with clientId %@ unknown, creating contact with id",memberClientId);
            memberContact = (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext:context];
            memberContact.type = [Contact entityName];
            memberContact.clientId = memberClientId;
            memberContact.nickName = kNickNewMember;
            memberContact.latestMessageTime = [self estimatedServerTime];
            
            [self.delegate saveContext:context];
        }
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
    if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: %d members, %d in filtered set",(int)group.members.count, (int)theMemberSet.count);
    
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
            if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: group has now %d members", (int)group.members.count);
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
        if ([@"none"isEqualToString: groupMemberDict[@"state"]]/* && ![myMembership.state isEqualToString:@"none"]*/) {
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
        
    //[self.delegate saveContext:context];
    
    if (memberShipDeleted) {
        // delete member
        if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"updateGroupMemberHere: schedule deleting member with state '%@', nick=%@", groupMemberDict[@"state"], memberContact.nickName);
        NSDate * myMemberVersion = myMembership.lastChanged;
        [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
            //[self.delegate performWithLockingId:memberClientId inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
                Group * group = [self getGroupById:groupId inContext:context];
                GroupMembership * myMembership = [group membershipWithClientId:memberClientId];
                Contact * memberContact = myMembership.contact;
                if (group != nil && myMembership != nil && memberContact != nil && [myMemberVersion isEqualToDate:myMembership.lastChanged]) {
                    if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"updateGroupMemberHere: perform deleting member with state '%@', nick=%@", myMembership.state, memberContact.nickName);
                    [self handleDeletionOfGroupMember:myMembership inGroup:group withContact:memberContact disinvited:disinvited inContext:context];
                } else {
                    if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"updateGroupMemberHere: not performing deleting member with state '%@', nick=%@", myMembership.state, memberContact.nickName);
                }
            }];
        }];
    } else {
        if (weHaveBeenInvited) {
            // we have been invited, but may not have enough data (e.g. presence information, admin membership) to present invitation alert, but we try
            // we also have to make this checks in the main context because group has some non-persistent flags here that exist only in the main context
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                Group * group = managedObjects[0];
                BOOL shouldPresentInvitation = [_groupsNotYetPresentedInvitation containsObject:group.clientId];
                if (GROUP_DEBUG) NSLog(@"updateGroupMemberHere: shouldPresentInvitation=%d for group %@ ",shouldPresentInvitation, group.clientId);
                if (!shouldPresentInvitation) {
                    [self tryPresentInvitationIfPossibleForGroup:group withMemberShip:myMembership];
                }
            }];
        } else {
            // we have not been invited in this call, but maybe this is our missing admin, so lets check
            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                Group * group = managedObjects[0];
                [self checkIfNeedToPresentInvitationForGroup:group];
            }];
            
        }
        if (someoneHasJoinedGroup) {
            [self groupJoinedAlertForGroupNamed:group.nickName withMemberNamed:memberContact.nickName];
        }
    }
    [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group]
                                                                              withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)
     {
         [context refreshObject: managedObjects[0] mergeChanges: YES];
     }];
    if (LOCKING_TRACE) NSLog(@"Done unsynchronized updateGroupMemberHere %@",groupId);
}

// will return true if the invitation is presented, false when there are not enough members to present it yes
// in this case the caller should set group.shouldPresentInvitation to YES and call checkIfNeedToPresentInvitationForGroupAfterNewPresenceOf:
// after presence of a new contact
- (void)tryPresentInvitationIfPossibleForGroup:(Group *) group withMemberShip:(GroupMembership*)myMembership {
    [self.delegate assertMainContext];
    if (!group.isIncompleteGroup && group.hasAdmin) {
        if (GROUP_DEBUG) NSLog(@"tryPresentInvitationIfPossibleForGroup: Presenting invitation alert for group %@ ",group.clientId);
        [self invitationAlertForGroup:group withMemberShip:myMembership];
        BOOL shouldPresentInvitation = [_groupsNotYetPresentedInvitation containsObject:group.clientId];
        if (shouldPresentInvitation) {
            [_groupsNotYetPresentedInvitation removeObject:group.clientId];
            if (GROUP_DEBUG) NSLog(@"tryPresentInvitationIfPossibleForGroup: removed _groupsNotYetPresentedInvitation entry for group %@ ",group.clientId);
        }
        return;
    }
    if (GROUP_DEBUG) NSLog(@"group %@ isIncompleteGroup=%d hasAdmin=%d, added _groupsNotYetPresentedInvitation entry ",group.clientId, group.isIncompleteGroup ,group.hasAdmin);
    [_groupsNotYetPresentedInvitation addObject:group.clientId];
}

// call after tryPresentInvitationIfPossibleForGroup failed when group information changes
- (void)checkIfNeedToPresentInvitationForGroup:(Group *)group {
    [self.delegate assertMainContext];
    BOOL shouldPresentInvitation = [_groupsNotYetPresentedInvitation containsObject:group.clientId];
    if (GROUP_DEBUG) NSLog(@"checkIfNeedToPresentInvitationForGroup for group %@ , shouldPresentInvitation=%d",group.clientId,shouldPresentInvitation);
    if (shouldPresentInvitation) {
        [self tryPresentInvitationIfPossibleForGroup:group withMemberShip:group.myGroupMembership];
    }
}

// call to see if the appeareance of a new presence will yield the admins presence so that
// the inviation can be presented
- (void)checkIfNeedToPresentInvitationForGroupAfterNewPresenceOf:(Contact *)contact {
    [self.delegate assertMainContext];
    if (GROUP_DEBUG) NSLog(@"checkIfNeedToPresentInvitationForGroupAfterNewPresenceOf for group %@ ",contact.clientId);
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
            // show group left alerts to all members if not a nearby or worldwide group
            if (!group.isNearbyGroup && !group.isWorldwideGroup) {
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
            (!memberContact.isDirectlyRelated && memberContact.groupMemberships.count == 1))
        {
            if (memberContact.messages.count > 0 || memberContact.deliveriesSent.count > 0 || [self.delegate isInspecting:memberContact]) {
                if (!group.isNearbyGroup && !group.isWorldwideGroup) {
                    [self askForDeletionOfContact:memberContact];
                }  else {
                    //autokeep
                    memberContact.relationshipState = kRelationStateInternalKept;
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
                    // show kicked from group alert if not a nearby or worldwide group
                    if (![kGroupTypeNearby isEqualToString:group.groupType] && ![kGroupTypeWorldwide isEqualToString:group.groupType]) {
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
    
    if (group.isNearbyGroup || group.isWorldwideGroup) {
        if (group.messages.count > 0 || [AppDelegate.instance isInspecting:group]) {
            if (DEBUG_DELETION) NSLog(@"handleDeletionOfGroup: is nearby or worldwide with messages, autokeeping group id %@",group.clientId);
            group.groupState = kRelationStateInternalKept;
            group.relationshipState = kRelationStateInternalKept;
            [self deleteInDatabaseAllMembersAndContactsofGroup:group inContext:context];
            [self.delegate saveContext:context];
            return;
        }
        if (DEBUG_DELETION) NSLog(@"handleDeletionOfGroup: is active nearby or worldwide, autokeeping group id %@",group.clientId);
    }
    
    NSString * groupId = group.clientId;
    @synchronized(_pendingGroupDeletions) {
        if (![_pendingGroupDeletions containsObject:groupId]) {
            [_pendingGroupDeletions addObject:groupId];
            if (group.messages.count == 0 && ![self.delegate isInspecting:group]) {
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
            NSArray * callerStack = [NSThread callStackSymbols];
            [self.delegate performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
                Group* group = (Group*)[context objectWithID:groupObjId];
                if (group == nil) {
                    NSLog(@"ERROR: group is nil, stack of caller = %@",callerStack);
                    return;
                }
                NSString * message = [NSString stringWithFormat: NSLocalizedString(@"group_deleted_message_format",nil), group.nickName];
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_deleted_title", nil)
                                                                 message: NSLocalizedString(message, nil)
                                                         completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                             switch (buttonIndex) {
                                                                 case 1:
                                                                     // delete all group member contacts that are not friends or contacts in other group
                                                                     [self deleteInDatabaseAllMembersAndContactsofGroup:group inContext:context];
                                                                     // delete the group
                                                                     if ([self ensureUnwindView:group]) {
                                                                         [AppDelegate.instance deleteObject:group inContext:context];
                                                                     } else {
                                                                         NSLog(@"#WARNING: could not unwind inspector of group, autokeeping");
                                                                         group.groupState = kRelationStateInternalKept;
                                                                         group.relationshipState = kRelationStateInternalKept;
                                                                     }
                                                                     
                                                                     break;
                                                                 case 0:
                                                                     group.groupState = kRelationStateInternalKept;
                                                                     group.relationshipState = kRelationStateInternalKept;
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

- (void) invitationAlertForGroup:(Group*)group withMemberShip:(GroupMembership*)member {
    [self.delegate assertMainContext];
    
    @synchronized(_groupsPresentingInvitation) {
        if ([_groupsPresentingInvitation containsObject:group.clientId]) {
            return;
        }
        [_groupsPresentingInvitation addObject:group.clientId];
    }

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
                                                        if (buttonIndex == 0) {
                                                            // join group
                                                            [self joinGroup:group onJoined:^(Group *group) {
                                                                if (group != nil) {
                                                                    if (GROUP_DEBUG) NSLog(@"Joined group %@", group);
                                                                } else {
                                                                    NSLog(@"ERROR: joinGroup %@ failed", group);
                                                                }
                                                                @synchronized(_groupsPresentingInvitation) {
                                                                    if ([_groupsPresentingInvitation containsObject:group.clientId]) {
                                                                        [_groupsPresentingInvitation removeObject:group.clientId];
                                                                    }
                                                                }
                                                            }];
                                                        } else if (buttonIndex == 1) {
                                                            // leave group
                                                            [self leaveGroup: group onGroupLeft:^(Group *group) {
                                                                if (group != nil) {
                                                                    if (GROUP_DEBUG) NSLog(@"TODO: Group left, now destroy everything (except our friends)");
                                                                } else {
                                                                    NSLog(@"ERROR: leaveGroup %@ failed", group);
                                                                }
                                                                @synchronized(_groupsPresentingInvitation) {
                                                                    if ([_groupsPresentingInvitation containsObject:group.clientId]) {
                                                                        [_groupsPresentingInvitation removeObject:group.clientId];
                                                                    }
                                                                }
                                                            }];
                                                        } else /*if (buttonIndex == 2)*/ {
                                                            // do nothing
                                                            @synchronized(_groupsPresentingInvitation) {
                                                                if ([_groupsPresentingInvitation containsObject:group.clientId]) {
                                                                    [_groupsPresentingInvitation removeObject:group.clientId];
                                                                }
                                                            }
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
    NSSet * groupMembers = [NSSet setWithSet:group.members];
    if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"deleteInDatabaseAllMembersAndContactsofGroup found %d members", (int)groupMembers.count);
    for (GroupMembership * member in groupMembers) {
        if (member.contact != nil && ![group isEqual:member.contact]) {
            if (!member.contact.isDirectlyRelated &&
                !member.contact.isKept &&
                member.contact.groupMemberships.count == 1)
            {
                if (member.contact.messages.count > 0 || member.contact.deliveriesSent.count > 0) {
                    // message in chat, ask for deletion
                    if (!member.group.isNearby && !member.group.isWorldwide) {
                        if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"ask for deletion of group member contact id %@", member.contact.clientId);
                        [self askForDeletionOfContact:member.contact];
                    } else {
                        // auto-keeping contact
                        if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"auto-keeping group member contact id %@", member.contact.clientId);
                        member.contact.relationshipState = kRelationStateInternalKept;
                    }
                } else {
                    // we can throw out this member contact without asking
                    if (GROUP_DEBUG || DEBUG_DELETION) NSLog(@"no messages deleting group member contact id %@", member.contact.clientId);
                    [AppDelegate.instance deleteObject:member.contact inContext:context];
                }
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
    
    //[self.delegate performWithLockingId:@"crypto" inNewBackgroundContext:^(NSManagedObjectContext *context) {
    [self.delegate performWithLockingId:kqContacts inNewBackgroundContext:^(NSManagedObjectContext *context) {
    
        id failed = @[];
        
        if (params.count != 5) {
            NSLog(@"getEncryptedGroupKeys() bad number of argument in params: %@, expected 5, got %d", params, (int)params.count);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
            return;
        }
        
        NSString * groupId = params[0];
        NSString * sharedKeyId = params[1];
        NSString * sharedKeyIdSalt = params[2];
        NSArray * clientIds = params[3];
        NSArray * publicKeyIds = params[4];
        
        if (groupId.length == 0 || sharedKeyId.length == 0 || sharedKeyIdSalt.length == 0 ||
            clientIds.count == 0 || publicKeyIds.count == 0 || clientIds.count != publicKeyIds.count)
        {
            NSLog(@"getEncryptedGroupKeys() missing or invalid argument in params: %@", params);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
            return;
        }
        Group * group = [self getGroupById: groupId inContext:context];
        if (group == nil) {
            NSLog(@"getEncryptedGroupKeys() unknown group with id : %@", groupId);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
            return;
        }
        if (![group.groupState isEqualToString:@"exists"]) {
            NSLog(@"getEncryptedGroupKeys() group not in state exist, id: %@", groupId);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                responder(failed);
            }];
            return;
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
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
                return;
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
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
                return;
            }
            if (!contact.hasPublicKey) {
                NSLog(@"getEncryptedGroupKeys() I have no public key for contact id: %@", clientIds[i]);
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
                return;
            }
            if (![contact.publicKeyId isEqualToString:publicKeyIds[i]]) {
                NSLog(@"getEncryptedGroupKeys() I have not the requested public key %@ for contact id: %@", publicKeyIds[i], clientIds[i]);
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
                return;
            }
            [contacts addObject:contact];
        }
        // ok, now we have all the ingredients to perform the request and can do the heavy lifting
        NSMutableArray * result = [NSMutableArray new];
        CCRSA * rsa = [CCRSA sharedInstance];
        for (int i = 0; i < clientIds.count;++i) {
            Contact * contact = (Contact*)contacts[i];
            SecKeyRef myReceiverKey = [contact getPublicKeyRef];
            if (myReceiverKey != nil) {
                NSData * keyBox = [rsa encryptWithKey:myReceiverKey plainData:group.groupKey];
                if (keyBox == nil) {
                    NSLog(@"#ERROR: getEncryptedGroupKeys() Encryption failed for key %@ contact id: %@", publicKeyIds[i], clientIds[i]);
                    [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                        responder(failed);
                    }];
                    return;
                }
                [result addObject:[keyBox asBase64EncodedString]];
            } else {
                NSLog(@"#ERROR: getEncryptedGroupKeys() get receiver key of contact failed for key %@ contact id: %@", publicKeyIds[i], clientIds[i]);
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    responder(failed);
                }];
                return;
            }
        }
        if (newSharedKeyId != nil && newSharedKeyIdSalt != nil) {
            [result addObject:newSharedKeyId];
            [result addObject:newSharedKeyIdSalt];
        }
        [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
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
#ifdef DEBUG_CHECK_FINISHED_UPLOADS
    [self checkReadyAttachmentUploads];
#endif
}


- (void) checkReadyAttachmentUploads {
    NSArray * readyAttachments = [self allReadyAttachmentUploads];
    for (Attachment * attachment in readyAttachments) {
        [self uploadFinished:attachment];
    }
}

-(NSArray*) allReadyAttachmentUploads {
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"AllOutgoingAttachments" substitutionVariables: @{}];
    
    NSError *error;
    NSArray *attachments = [self.delegate.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (attachments == nil)
    {
        NSLog(@"Fetch request for 'AllOutgoingAttachments' failed: %@", error);
        abort();
    }
    NSMutableArray * readyAttachments = [[NSMutableArray alloc]init];
    for (Attachment * attachment in attachments) {
        AttachmentState attachmentState = attachment.state;
        if (attachmentState == kAttachmentTransfered)
        {
            [readyAttachments enqueue:attachment];
        }
    }
    return readyAttachments;
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
    if (TRANSFER_DEBUG) NSLog(@"flushPendingAttachmentUploads found %d unfinished uploads", (int)unfinishedAttachments.count);
    NSMutableArray * pendingAttachments = [NSMutableArray array];
    for (Attachment * attachment in unfinishedAttachments) {
        Delivery * delivery = attachment.message.deliveries.anyObject;
        if (delivery.attachmentUploadable) {
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
    if (TRANSFER_DEBUG) NSLog(@"flushPendingAttachmentDownloads found %d unfinished downloads", (int)unfinishedAttachments.count);
    NSMutableArray * pendingAttachments = [[NSMutableArray alloc]init];
    for (Attachment * attachment in unfinishedAttachments) {
        Delivery * delivery = attachment.message.deliveries.anyObject;
        if (delivery.attachmentDownloadable) {
            [pendingAttachments enqueue:attachment];
        }
    }
    return pendingAttachments;
}

- (void) flushPendingAttachmentDownloads {
    NSArray * pendingAttachments = [self pendingAttachmentDownloads];
    for (Attachment * attachment in pendingAttachments) {
        if (attachment.downloadable) {
            [self enqueueDownloadOfAttachment:attachment];
        }
#ifdef DEBUG_TEST_DOWNLOAD
        [self testAttachmentDownload:attachment];
#endif
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
    [self checkDowloadQueue];
    [self checkUploadQueue];
}

- (void)checkDowloadQueue {
    if (TRANSFER_DEBUG) NSLog(@"checkDowloadQueue");
    NSArray * da = [_attachmentDownloadsActive copy];
    for (Attachment * a in da) {
        if (a.state != kAttachmentTransfering && a.state != kAttachmentTransferScheduled) {
            NSLog(@"#WARNING: checkDowloadQueue : attachment with bad state %@ in _attachmentDownloadsActive, dequeueing url = %@", [Attachment getStateName:a.state], a.remoteURL);
            [self dequeueDownloadOfAttachment:a];
        }
    }
    NSArray * pendingDownloads = [self pendingAttachmentDownloads];
    for (Attachment * a in pendingDownloads) {
        if ([_attachmentDownloadsWaiting indexOfObject:a] == NSNotFound && [_attachmentDownloadsActive indexOfObject:a] == NSNotFound) {
            NSLog(@"#WARNING: checkDowloadQueue : attachment with state %@ not in transfer queues, enqueuing download, url = %@", [Attachment getStateName:a.state], a.remoteURL);
            [self enqueueDownloadOfAttachment:a];
        }
    }
    
    if (TRANSFER_DEBUG) NSLog(@"checkDowloadQueue ready");
}

- (void)checkUploadQueue {
    if (TRANSFER_DEBUG) NSLog(@"checkUploadQueue");
    NSArray * da = [_attachmentUploadsActive copy];
    for (Attachment * a in da) {
        if (a.state != kAttachmentTransfering && a.state != kAttachmentTransferScheduled) {
            NSLog(@"#WARNING: checkUploadQueue : attachment with bad state %@ in _attachmentUploadsActive, dequeueing url = %@", [Attachment getStateName:a.state], a.uploadURL);
            [self dequeueUploadOfAttachment:a];
        }
    }
    NSArray * pendingUploads = [self pendingAttachmentUploads];
    for (Attachment * a in pendingUploads) {
        if ([_attachmentUploadsWaiting indexOfObject:a] == NSNotFound && [_attachmentUploadsActive indexOfObject:a] == NSNotFound) {
            NSLog(@"#WARNING: checkUploadQueue : attachment with state %@ not in transfer queues, enqueuing upload, url = %@", [Attachment getStateName:a.state], a.uploadURL);
            [self enqueueUploadOfAttachment:a];
        }
    }
    if (TRANSFER_DEBUG) NSLog(@"checkUploadQueue ready");
}


-(BOOL) alreadyInDowloadQueue:(Attachment*)attachment {
    return [_attachmentDownloadsWaiting indexOfObject:attachment] != NSNotFound ||
        [_attachmentDownloadsActive indexOfObject:attachment] != NSNotFound;
}

- (void) enqueueDownloadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment %@ state %@", theAttachment.remoteURL, [Attachment getStateName:theAttachment.state]);
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment before active=%d, waiting=%d", (int)_attachmentDownloadsActive.count, (int)_attachmentDownloadsWaiting.count);
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
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachment after active=%d, waiting=%d", (int)_attachmentDownloadsActive.count, (int)_attachmentDownloadsWaiting.count);
    [self updateNetworkActivityIndicator];
}

- (void) enqueueUploadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment %@", theAttachment.uploadURL);
    if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment before active=%d, waiting=%d", (int)_attachmentUploadsActive.count, (int)_attachmentUploadsWaiting.count);
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
    if (TRANSFER_DEBUG) NSLog(@"enqueueUploadOfAttachment after active=%d, waiting=%d", (int)_attachmentUploadsActive.count, (int)_attachmentUploadsWaiting.count);
    [self updateNetworkActivityIndicator];
}

- (void) updateNetworkActivityIndicator {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(_attachmentUploadsActive.count > 0 || _attachmentDownloadsActive.count > 0)];
}

- (void) dequeueDownloadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment %@", theAttachment.remoteURL);
    if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment before active=%d, waiting=%d", (int)_attachmentDownloadsActive.count, (int)_attachmentDownloadsWaiting.count);
    NSUInteger index = [_attachmentDownloadsActive indexOfObject:theAttachment];
    if (index != NSNotFound) {
        [_attachmentDownloadsActive removeObjectAtIndex:index];
        if (_attachmentDownloadsWaiting.count > 0) {
            [self sortByTransferDate:_attachmentDownloadsWaiting];
            [self enqueueDownloadOfAttachment:[_attachmentDownloadsWaiting dequeue]];
        }
        if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment (a) after active=%d, waiting=%d", (int)_attachmentDownloadsActive.count, (int)_attachmentDownloadsWaiting.count);
    } else {
        // in case it is in the waiting queue remove it from there
        [_attachmentDownloadsWaiting removeObject:theAttachment];
        if (TRANSFER_DEBUG) NSLog(@"dequeueDownloadOfAttachment (b) after active=%d, waiting=%d", (int)_attachmentDownloadsActive.count, (int)_attachmentDownloadsWaiting.count);
    }
    [self updateNetworkActivityIndicator];
}

- (void) dequeueUploadOfAttachment:(Attachment*) theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment %@", theAttachment.uploadURL);
    if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment before active=%d, waiting=%d", (int)_attachmentUploadsActive.count, (int)_attachmentUploadsWaiting.count);
    NSUInteger index = [_attachmentUploadsActive indexOfObject:theAttachment];
    if (index != NSNotFound) {
        [_attachmentUploadsActive removeObjectAtIndex:index];
        if (_attachmentUploadsWaiting.count > 0) {
            [self sortBySizeTodo:_attachmentUploadsWaiting];
            [self enqueueUploadOfAttachment:[_attachmentUploadsWaiting dequeue]];
        }
        if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment (a) after active=%d, waiting=%d", (int)_attachmentUploadsActive.count, (int)_attachmentUploadsWaiting.count);
    } else {
        // in case it is in the waiting queue remove it from there
        [_attachmentUploadsWaiting removeObject:theAttachment];
    }
    if (TRANSFER_DEBUG) NSLog(@"dequeueUploadOfAttachment (b) after active=%d, waiting=%d", (int)_attachmentUploadsActive.count, (int)_attachmentUploadsWaiting.count);
    [self updateNetworkActivityIndicator];
}

- (void) downloadFinished:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"downloadFinished of %@", theAttachment.remoteURL);
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self updateAttachmentInDeliveryStateIfNecessary:theAttachment];
    [self dequeueDownloadOfAttachment:theAttachment];
    [SoundEffectPlayer messageArrived];
}

- (void) uploadStarted:(Attachment *)theAttachment {
    [self startedFileUpload:theAttachment.message.attachmentFileId withhandler:^(NSString *result, BOOL ok) {
        if (ok) {
            if (![kDelivery_ATTACHMENT_STATE_UPLOADING isEqualToString:result]) {
                NSLog(@"startedFileUpload for file %@ returned strange attachment state %@",theAttachment.message.attachmentFileId, result);
            }
        }
    }];
}

- (void) uploadPaused:(Attachment *)theAttachment {
    [self pausedFileUpload:theAttachment.message.attachmentFileId withhandler:^(NSString *result, BOOL ok) {
        if (ok) {
            if (![kDelivery_ATTACHMENT_STATE_UPLOAD_PAUSED isEqualToString:result]) {
                NSLog(@"pausedFileUpload for file %@ returned strange attachment state %@",theAttachment.message.attachmentFileId, result);
            }
        }
    }];
}

- (void) uploadFinished:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"uploadFinished of %@", theAttachment.uploadURL);
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    [self finishedFileUpload:theAttachment.message.attachmentFileId withhandler:^(NSString *result, BOOL ok) {
        if (ok) {
            if (![kDelivery_ATTACHMENT_STATE_UPLOADED isEqualToString:result] &&
                ![kDelivery_ATTACHMENT_STATE_RECEIVED isEqualToString:result]) // receiver might have been faster and has already signalled reception to server
            {
                NSLog(@"finishedFileUpload for file %@ returned strange attachment state %@",theAttachment.message.attachmentFileId, result);
            }
        }
    }];
    [self dequeueUploadOfAttachment:theAttachment];
    [self checkUploadQueue];
#ifdef DEBUG_CHECK_FINISHED_UPLOADS
    [self checkUploadStatus:theAttachment.uploadURL hasSize:[theAttachment.cipherTransferSize longLongValue]  withCompletion:^(NSString *url, long long transferedSize, BOOL ok) {
        if (!ok) {
            NSLog(@"Upload check failed for Attachment url %@, uploaded = %lld, rescheduling",url,transferedSize);
#ifdef REUPLOAD_WHEN_CHECK_FAILS
            if (transferedSize > 32) {
                theAttachment.transferSize = [NSNumber numberWithLongLong:transferedSize - 31];
            } else {
                theAttachment.transferSize = [NSNumber numberWithLongLong:1];
            }
            [self uploadFailed:theAttachment];
#endif
        } else {
            NSLog(@"Upload check ok for Attachment url %@, uploaded = %lld",url,transferedSize);
        }
    }];
#endif
#ifdef DEBUG_TEST_DOWNLOAD
    [self testAttachmentDownload:theAttachment];
#endif
}

- (void)testAttachmentDownload:(Attachment*)theAttachment {
    NSLog(@"testAttachmentDownload url %@",theAttachment.remoteURL);
    [HXOBackend downloadDataFromURL:theAttachment.remoteURL inQueue:_avatarDownloadQueue withCompletion:^(NSData * data, NSError * error) {
        if (data != nil && error == nil) {
            if ([data length] == [theAttachment.cipherTransferSize longValue]) {
                NSLog(@"Download check ok for Attachment url %@",theAttachment.remoteURL);
            } else {
                NSLog(@"Download check size mismtach for Attachment url %@, should be %@, was %@", theAttachment.remoteURL,theAttachment.cipherTransferSize, @(data.length));
            }
        } else {
            NSLog(@"Download check failed for Attachment url %@, error=%@, reason=%@",theAttachment.remoteURL,error.localizedDescription,error.localizedFailureReason);
        }
    }];
}

/*

- (void) enqueueDownloadOfAttachmentIfSensible:(Attachment *)theAttachment {
    Delivery * delivery = theAttachment.message.deliveries.anyObject;
    AttachmentState state = theAttachment.state;
    if (TRANSFER_DEBUG) NSLog(@"enqueueDownloadOfAttachmentIfSensible: check if enque download of attachment with state '%@' and deliveryState '%@'", [Attachment getStateName:state], delivery.attachmentState);
    if ((state == kAttachmentUploadIncomplete || state == kAttachmentDownloadIncomplete || state == kAttachmentWantsTransfer) &&
        delivery.attachmentDownloadable)
    {
        if (TRANSFER_DEBUG) NSLog(@"enqueueing attachment %@", theAttachment.remoteURL);
        [self enqueueDownloadOfAttachment:theAttachment];
    } else {
        if (TRANSFER_DEBUG) NSLog(@"not enqueueing attachment %@", theAttachment.remoteURL);
    }
}
*/

- (void) updateAttachmentInDeliveryStateIfNecessary:(Attachment *)theAttachment {
    NSString * fileId = theAttachment.message.attachmentFileId;
    
    BOOL pending;
    @synchronized(_pendingAttachmentDeliveryUpdates) {pending = [_pendingAttachmentDeliveryUpdates containsObject:fileId];}
    if (pending) {
        if (DELIVERY_TRACE) NSLog(@"updateAttachmentInDeliveryStateIfNecessary: postponing attachment state update for fileId '%@'", fileId);
        
        @synchronized(_postponedAttachmentDeliveryUpdates) {[_postponedAttachmentDeliveryUpdates addObject:fileId];}
        /*
        // TODO: move to when request ready instead of delay
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 4.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self updateAttachmentInDeliveryStateIfNecessary:theAttachment];
        });
         */
    } else {
        Delivery * delivery = theAttachment.message.deliveries.anyObject;
        AttachmentState state = theAttachment.state;
        
        if (DELIVERY_TRACE) NSLog(@"updateAttachmentInDeliveryStateIfNecessary: check if update server delivery about attachment with state '%@' and deliveryState '%@'", [Attachment getStateName:state], delivery.attachmentState);
        
        if ([kDelivery_ATTACHMENT_STATE_UPLOADING isEqualToString:delivery.attachmentState] ||
            [kDelivery_ATTACHMENT_STATE_UPLOADED isEqualToString:delivery.attachmentState]) {
            if (state == kAttachmentTransfered) {
                @synchronized(_pendingAttachmentDeliveryUpdates) {[_pendingAttachmentDeliveryUpdates addObject:fileId];}
                [self receivedFile:fileId withhandler:^(NSString *result, BOOL ok) {
                    if (ok) {
                        if (![kDelivery_ATTACHMENT_STATE_RECEIVED isEqualToString:result]) {
                            NSLog(@"receivedFile for file %@ returned strange attachment state %@",fileId, result);
                        }
                        NSArray * ids = permanentObjectIds(@[delivery]);
                        [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
                            NSArray * object = existingManagedObjects(ids, context);
                            if (object) {
                                Delivery * delivery = object[0];
                                delivery.attachmentState = result;
                            }
                            @synchronized(_pendingAttachmentDeliveryUpdates) {[_pendingAttachmentDeliveryUpdates removeObject:fileId];}
                            @synchronized(_postponedAttachmentDeliveryUpdates) {
                                if ([_postponedAttachmentDeliveryUpdates containsObject:fileId]) {
                                    [_postponedAttachmentDeliveryUpdates removeObject:fileId];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self updateAttachmentInDeliveryStateIfNecessary:theAttachment];
                                    });
                                };
                            }
                        }];
                    }
                }];
            } else if (state == kAttachmentTransfersExhausted) {
                
                @synchronized(_pendingAttachmentDeliveryUpdates) {[_pendingAttachmentDeliveryUpdates addObject:fileId];}

                [self failedFileDownload:fileId withhandler:^(NSString *result, BOOL ok) {
                    if (ok) {
                        if (![kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED isEqualToString:result]) {
                            NSLog(@"failedFileDownload for file %@ returned strange attachment state %@",fileId, result);
                        }
                        NSArray * ids = permanentObjectIds(@[delivery]);
                        [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
                            NSArray * object = existingManagedObjects(ids, context);
                            if (object) {
                                Delivery * delivery = object[0];
                                delivery.attachmentState = result;
                            }
                            @synchronized(_pendingAttachmentDeliveryUpdates) {[_pendingAttachmentDeliveryUpdates removeObject:fileId];}
                            @synchronized(_postponedAttachmentDeliveryUpdates) {
                                if ([_postponedAttachmentDeliveryUpdates containsObject:fileId]) {
                                    [_postponedAttachmentDeliveryUpdates removeObject:fileId];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self updateAttachmentInDeliveryStateIfNecessary:theAttachment];
                                    });
                                };
                            }
                        }];
                    }
                }];
            }
        }
    }
}

- (void) downloadFailed:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"downloadFailed of %@", theAttachment.remoteURL);
    theAttachment.transferFailures = theAttachment.transferFailures + 1;
    theAttachment.transferFailed = [[NSDate alloc] init];
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    if (theAttachment.state == kAttachmentTransfersExhausted) {
        [self failedFileDownload:theAttachment.message.attachmentFileId withhandler:^(NSString *result, BOOL ok) {
        }];
    }
    [self dequeueDownloadOfAttachment:theAttachment];
    if (theAttachment.downloadable) {
        [self enqueueDownloadOfAttachment:theAttachment];
    }
}

- (void) uploadFailed:(Attachment *)theAttachment {
    if (TRANSFER_DEBUG) NSLog(@"uploadFailed of %@", theAttachment.uploadURL);
    theAttachment.transferFailures = theAttachment.transferFailures + 1;
    theAttachment.transferFailed = [[NSDate alloc] init];
    [self.delegate.mainObjectContext refreshObject: theAttachment.message mergeChanges:YES];
    [self.delegate saveDatabase];
    if (theAttachment.state == kAttachmentTransfersExhausted) {
        [self failedFileUpload:theAttachment.message.attachmentFileId withhandler:^(NSString *result, BOOL ok) {
        }];
    } else {
        [self pausedFileUpload:theAttachment.message.attachmentFileId withhandler:^(NSString *result, BOOL ok) {
        }];
    }
    [self dequeueUploadOfAttachment:theAttachment];
    [self enqueueUploadOfAttachment:theAttachment];
    [self checkUploadQueue];
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
    if (TRANSFER_DEBUG) NSLog(@"scheduleNewTransferFor:%@", theAttachment.remoteURL);
    
    if (theAttachment.transferRetryTimer != nil) {
        if (TRANSFER_DEBUG) NSLog(@"scheduleNewTransferFor:%@ invalidating timer for transfer in %f secs", theAttachment.remoteURL, [[theAttachment.transferRetryTimer fireDate] timeIntervalSinceNow]);
        [theAttachment.transferRetryTimer invalidate];
        theAttachment.transferRetryTimer = nil;
    }
    if (![self.delegate.internetReachabilty isReachable]) {
        // do not schedule retrys without internet connection
        if (TRANSFER_DEBUG) NSLog(@"No Internet, not scheduling: scheduleNewTransferFor:%@ failures = %i, retry in = %f secs",theAttachment.outgoing ? theAttachment.uploadURL: theAttachment.remoteURL, (int)theAttachment.transferFailures, retryTime);
        return;
    }
    if (theAttachment.state == kAttachmentUploadIncomplete ||
        theAttachment.state == kAttachmentDownloadIncomplete ||
        theAttachment.state == kAttachmentWantsTransfer) {
        if (TRANSFER_DEBUG) NSLog(@"scheduleNewTransferFor:%@ , retry in = %f secs, failures = %i",theAttachment.outgoing ? theAttachment.uploadURL: theAttachment.remoteURL, retryTime, (int)theAttachment.transferFailures);
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
              theAttachment.outgoing ? theAttachment.uploadURL : theAttachment.remoteURL, (int)theAttachment.transferFailures);
    } else  if (theAttachment.state == kAttachmentTransfered) {
        NSLog(@"scheduleTransferRetryFor: attachment %@ already transfered, state=%@",
              theAttachment.outgoing ? theAttachment.uploadURL : theAttachment.remoteURL, [Attachment getStateName:theAttachment.state]);
    } else {
        NSLog(@"#ERROR:scheduleTransferRetryFor: weird state for attachment %@, no transfer scheduled, state=%@",
                                  theAttachment.outgoing ? theAttachment.uploadURL : theAttachment.remoteURL, [Attachment getStateName:theAttachment.state]);
        NSLog(@"%@",theAttachment);

        
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
	
    //NSLog(@"httpRequest method: %@ url: %@", method, URLString);
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
    //[request setHTTPShouldUsePipelining:NO];
    
    if (TRANSFER_DEBUG) NSLog(@"httpRequest method: %@ url: %@ headers: %@", method, URLString, headers);

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

- (void) finishedIncoming: (GenericResultHandler) handler {
    [_serverConnection invoke: @"finishedIncoming" withParams: nil onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(YES);
        } else {
            NSLog(@"finishedIncoming failed: %@", responseOrError);
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
            NSLog(@"generateId failed: %@", responseOrError);
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

- (void) srpChangeVerifierWithHandler:(GenericResultHandler)handler {
    [[UserProfile sharedProfile] backupCredentialsWithId:@"old"];
    NSString * verifier = [[UserProfile sharedProfile] registerClientAndComputeVerifier: [UserProfile sharedProfile].clientId];
    NSString * salt = [UserProfile sharedProfile].salt;
    [[UserProfile sharedProfile] backupCredentialsWithId:@"new"];
    
    //NSLog(@"srpChangeVerifier: %@ andSalt: %@", verifier, salt);
    [_serverConnection invoke: @"srpChangeVerifier" withParams: @[verifier, salt] onResponse: ^(id responseOrError, BOOL success) {
        if ( ! success) {
            NSLog(@"ERROR - verifier change failed: %@ - restoring old verifier", responseOrError);
            [[UserProfile sharedProfile] restoreCredentialsWithId:@"old" withForce:YES];
            [[UserProfile sharedProfile] removeCredentialsBackupWithId:@"old"];
            // TODO: if we have failed, the server might have changed to the new credentials anyway
            // these are stored under id "new", so we might try to recover from this problem
            // but it will be probably very rare
            handler(NO);
        } else {
            NSLog(@"INFO: verifier change succeeded");
            [[UserProfile sharedProfile] backupCredentials];
            [[UserProfile sharedProfile] removeCredentialsBackupWithId:@"old"];
            [[UserProfile sharedProfile] removeCredentialsBackupWithId:@"new"];
            handler(YES);
        }
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

- (void)deleteAccountForReason:(NSString *)reason  handler:(GenericResultHandler)handler{
    [_serverConnection invoke: @"deleteAccount" withParams: @[reason] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            handler(YES);
        } else {
            NSLog(@"deleteAccount failed: %@", responseOrError);
            handler(NO);
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
#ifdef DEBUG
    NSString * clientBuildVariant = @"debug";
#else
    NSString * clientBuildVariant = @"release";
#endif
    NSDictionary * initParams = @{
                             @"clientTime"     : clientTime,
                             @"systemLanguage" : [[NSLocale preferredLanguages] objectAtIndex:0],
                             @"deviceModel"    : machineName,
                             @"systemName"     : [UIDevice currentDevice].systemName,
                             @"systemVersion"  : [UIDevice currentDevice].systemVersion,
                             @"clientName"     : [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                             @"clientBuildVariant" : clientBuildVariant,
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

- (void) helloWithCompletion:(GenericResultHandler)completion {
    NSNumber * clientTime = [HXOBackend millisFromDate:[NSDate date]];
    [self hello:clientTime
      crashFlag:self.firstConnectionAfterCrashOrUpdate && _delegate.launchedAfterCrash
     updateFlag:self.firstConnectionAfterCrashOrUpdate && _delegate.runningNewBuild
        unclean: _uncleanConnectionShutdown
        handler:^(NSDictionary * result)
    {
        if (result != nil) {
            self.serverInfo = result;
            if (completion) completion(YES);
        } else {
            if (completion) completion(NO);
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

// client calls this method to send a Talkmessage along with the intended recipients in the deliveries array
// the return result contains an array with updated deliveries
- (void) outDeliveryRequest: (HXOMessage*) message withDeliveries: (NSArray*) deliveries withCompletion:(GenericResultHandler)completion {
    message.messageId = nil;
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
    
    [_serverConnection invoke: @"outDeliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSArray * messageObjIds = permanentObjectIds(@[message]);
            if (messageObjIds == nil) {
                NSLog(@"outDeliveryRequest: could not obtain permanent id for message, ignoring result");
                return;
            }

            NSManagedObjectID * messageObjId = messageObjIds[0];;
            NSArray * deliveryIds = permanentObjectIds(deliveries);
            if (deliveryIds == nil) {
                NSLog(@"outDeliveryRequest: could not obtain permanent ids for some deliveries, ignoring result");
                return;
            }
            //NSArray * resultDeliveryDicts = (NSArray*)responseOrError;
            //NSDictionary * dict = resultDeliveryDicts[0];
            
            //NSString * lockid = [self chatLockForSenderId:dict[@"messageId"] andGroupId:dict[@"groupId"]];
            
            //[self.delegate performWithLockingId:lockid inNewBackgroundContext:^(NSManagedObjectContext *context) {
            [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
                NSArray * deliveries = existingManagedObjects(deliveryIds,context);
                if (deliveries == nil) {
                    NSLog(@"outDeliveryRequest: some deliveries are gone, igonring result");
                    return;
                }
                NSError * error = nil;
                HXOMessage * message = (HXOMessage*)[context existingObjectWithID:messageObjId error:&error];
                if (message == nil || error != nil) {
                    NSLog(@"outDeliveryRequest: message is gone, ignoring result");
                    return;
                }
                
                NSArray * updatedDeliveryDicts = (NSArray*)responseOrError;
                if (deliveries.count == 1) { // we did send 1 delivery
                    Delivery * delivery = deliveries[0];
                    
                    // handle group delivery
                    if (delivery.isGroupDelivery) {
                        int expandedGroupDeliveries = 0;
                        for (NSDictionary * deliveryDict in updatedDeliveryDicts) {
                            if (deliveryDict[@"receiverId"] != nil) {
                                expandedGroupDeliveries++;
                            }
                        }
                        if (expandedGroupDeliveries == updatedDeliveryDicts.count) {
                            // handle "good" return from group delivery
                            Group * group = nil;

                            // we received new, expanded group deliveries, so lets get rid of the old group delivery
                            [self.delegate deleteObject:delivery inContext:context];
                            
                            NSDate * acceptedTime = nil;
                            for (NSDictionary * deliveryDict in updatedDeliveryDicts) {
                                Delivery * newDelivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: context];
                                //[message.deliveries addObject: newDelivery];
                                newDelivery.message = message;
                                group = [self getGroupById:deliveryDict[@"groupId"] inContext:context];
                                if (group == nil) {
                                    NSLog(@"### failed get group %@", deliveryDict[@"groupId"]);
                                    continue;
                                }
                                newDelivery.group = group;
                                newDelivery.receiver = [self getContactByClientId:deliveryDict[@"receiverId"] inContext:context];
                                
                                if (DELIVERY_TRACE) NSLog(@"### inserted delivery for group %@ and receiver %@", newDelivery.group.clientId, newDelivery.receiver.clientId);
                                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                                    [self outgoingDeliveryUpdated:@[deliveryDict] isResult:YES onDone:nil];
                                }];
                                if (acceptedTime == nil) {
                                    acceptedTime = [HXOBackend dateFromMillis:deliveryDict[@"timeAccepted"]];
                                }
                            }
                            message.timeAccepted = acceptedTime;

                            // be aware that the following block will be probably executed
                            // before the above outgoingDeliveryUpdated will have finished
                            // because they run in background
                            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[group, message] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                                Group * group = managedObjects[0];
                                HXOMessage * message = managedObjects[1];
                                group.latestMessageTime = acceptedTime;
                                [self.delegate saveContext];
                                [context refreshObject: message mergeChanges: YES];
                                if (DELIVERY_TRACE) {NSLog(@"Delivery message time update: messageId = %@, message.timeAccepted=%@, group.latestMessageTime=%@, msgMillis=%@, groupMillis=%@",message.messageId, message.timeAccepted, group.latestMessageTime, [HXOBackend millisFromDate:message.timeAccepted], [HXOBackend millisFromDate:group.latestMessageTime] );}
                                completion(YES);
                            }];
                            return;
                        }
                    }
                }
                // not a group delivery or group delivery failed to expand
                
                // NSLog(@"deliveryRequest() returned deliveries: %@", responseOrError);
                int i = 0;
                for (Delivery * delivery in deliveries) {
                    if (USE_VALIDATOR) [self validateObject: updatedDeliveryDicts[i] forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
                    if (DELIVERY_TRACE) {NSLog(@"deliveryRequest result: Delivery state '%@'->'%@' for messageTag %@ id %@",delivery.state, updatedDeliveryDicts[i][@"state"], updatedDeliveryDicts[i][@"messageTag"],updatedDeliveryDicts[i][@"messageId"] );}
                    
                    // update the message fields only from the first delivery
                    if (i == 0) {
                        [delivery updateWithDictionary: updatedDeliveryDicts[i++]];
                    } else {
                        [delivery updateWithDictionary:updatedDeliveryDicts[i++] withKeys:[Delivery updateRpcKeys]];
                    }
                    
                    if (delivery.group != nil) {
                        delivery.group.latestMessageTime = message.timeAccepted;
                    } else {
                        // update receiver time only when not a group message
                        if (delivery.receiver != nil) {
                            delivery.receiver.latestMessageTime = message.timeAccepted;
                        }
                    }
                    if (DELIVERY_TRACE) {NSLog(@"Delivery message time update: messageId = %@, message.timeAccepted=%@, delivery.receiver.latestMessageTime=%@, delivery.group.latestMessageTime=%@",message.messageId, message.timeAccepted, delivery.receiver.latestMessageTime, delivery.group.latestMessageTime);}
                }
                
                //[self.delegate saveContext:context]; // make sure all objects have their proper ids before passing to other context by saving the context
                
                for (Delivery * delivery in deliveries) {
                    if (delivery.group != nil) {
                        [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[delivery.group] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                            [context refreshObject: managedObjects[0] mergeChanges: YES];
                        }];
                    } else {
                        if (delivery.receiver != nil) {
                            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[delivery.receiver] withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                                [context refreshObject: managedObjects[0] mergeChanges: YES];
                            }];
                        }
                    }
                }
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    completion(YES);
                }];
            }];
        } else {
            NSLog(@"deliveryRequest failed: %@", responseOrError);
            completion(NO);
        }
    }];
}


- (void) inDeliveryConfirmWithMethod:(NSString*)method withMessageId:(NSString*) messageId withDelivery: (Delivery*) delivery {
    // NSLog(@"deliveryConfirm: %@", delivery);
    [_serverConnection invoke: method withParams: @[messageId] onResponse: ^(id responseOrError, BOOL success) {
        if (responseOrError != nil && [responseOrError isKindOfClass:[NSDictionary class]]) {
            if (success) {
                if (DELIVERY_TRACE) {NSLog(@"inDeliveryConfirm %@ result: state %@->%@ for messageTag %@",method, delivery.state, responseOrError[@"state"], delivery.message.messageTag);}
                if ([delivery.state isEqualToString: responseOrError[@"state"]]) {
                    if (GLITCH_TRACE) {NSLog(@"#GLITCH: inDeliveryConfirm %@result: state unchanged %@->%@ for messageTag %@",method,delivery.state, responseOrError[@"state"], delivery.message.messageTag);}
                }
                [self incomingDeliveryUpdated:@[responseOrError]];
                if (self.delegate.processingBackgroundNotification) {
                    [self finishedIncoming:^(BOOL ok) {
                        if (ok) {
                            NSLog(@"inDeliveryConfirm : finishedIncoming ok");
                        } else {
                            NSLog(@"inDeliveryConfirm : finishedIncoming failed");
                        }
                    }];
                }
            } else {
                // it might happen that a delivery is gone on the server, but we still have it
                // in these cases we will get an error with result code 0 and set the delivery state to unknown so
                // we do not try to confirm it again and again on startup
                NSLog(@"#ERROR: inDeliveryConfirm %@ failed, response: %@", method, responseOrError);
                NSDictionary * myDict = (NSDictionary*)responseOrError;
                NSNumber * errorCode = myDict[@"code"];
                if (errorCode != nil && errorCode.intValue == 0) {
                    NSLog(@"inDeliveryConfirm : setting delivery state to ‘unknown'");
                    delivery.state = @"unknown";
                }
            }
        }
    }];
}

- (void) inDeliveryConfirmPrivate: (NSString*) messageId withDelivery: (Delivery*) delivery {
    [self inDeliveryConfirmWithMethod:@"inDeliveryConfirmPrivate" withMessageId:messageId withDelivery:delivery];
}
- (void) inDeliveryConfirmSeen: (NSString*) messageId withDelivery: (Delivery*) delivery {
    [self inDeliveryConfirmWithMethod:@"inDeliveryConfirmSeen" withMessageId:messageId withDelivery:delivery];
}
- (void) inDeliveryConfirmUnseen: (NSString*) messageId withDelivery: (Delivery*) delivery {
    [self inDeliveryConfirmWithMethod:@"inDeliveryConfirmUnseen" withMessageId:messageId withDelivery:delivery];
}

- (void) outDeliveryAcknowledgeMethod:(NSString*)method
                    withExpectedState:(NSString*)expected
                        withMessageId:(NSString*)messageId
                       withReceiverId:(NSString*)receiverId
                              onReady:(DoneBlock)done
{
    if (DELIVERY_TRACE) {NSLog(@"outDeliveryAcknowledgeMethod: (%@) messageId=%@, receiverId=%@", method, messageId,receiverId);}
    
    if (method == nil || messageId == nil || receiverId == nil) {
        NSLog(@"#ERROR: outDeliveryAcknowledgeMethod: bad paramters: method:%@ messageId:%@ receiverId:%@",method, messageId, receiverId);
        return;
    }
    
    [_serverConnection invoke: method withParams: @[messageId, receiverId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success && responseOrError != nil && [responseOrError isKindOfClass:[NSDictionary class]]) {
             if (USE_VALIDATOR) [self validateObject: responseOrError forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
             
             if (![responseOrError isKindOfClass:[NSDictionary class]]) {
                 NSLog(@"ERROR: outDeliveryAcknowledgeMethod (%@) response is null", method);
                 return;
             }
             if (![expected isEqualToString: responseOrError[@"state"]]) {
                 NSLog(@"ERROR: outDeliveryAcknowledgeMethod (%@), unexpected response state %@, expected %@", method, responseOrError[@"state"], expected);
             }
             [self outgoingDeliveryUpdated:@[responseOrError] isResult:YES onDone:done];
         } else {
             NSLog(@" outDeliveryAcknowledgeMethod (%@) failed, response: %@", method, responseOrError);
         }
     }];
}

// As sender, acknowledge a "delivered" delivery

- (void) outDeliveryAcknowledgeUnseen: (NSString*)messageId withReceiverId:(NSString*)receiverId onReady:(DoneBlock)done {
    [self outDeliveryAcknowledgeMethod:@"outDeliveryAcknowledgeUnseen"
                     withExpectedState:kDeliveryStateDeliveredUnseenAcknowledged
                         withMessageId:messageId withReceiverId:receiverId
                               onReady:done
     ];
}

- (void) outDeliveryAcknowledgeSeen: (NSString*)messageId withReceiverId:(NSString*)receiverId onReady:(DoneBlock)done {
    [self outDeliveryAcknowledgeMethod:@"outDeliveryAcknowledgeSeen"
                     withExpectedState:kDeliveryStateDeliveredSeenAcknowledged
                         withMessageId:messageId
                        withReceiverId:receiverId
                               onReady:done
     ];
}

- (void) outDeliveryAcknowledgePrivate: (NSString*)messageId withReceiverId:(NSString*)receiverId onReady:(DoneBlock)done {
    [self outDeliveryAcknowledgeMethod:@"outDeliveryAcknowledgePrivate"
                     withExpectedState:kDeliveryStateDeliveredPrivateAcknowledged
                         withMessageId:messageId
                        withReceiverId:receiverId
                               onReady:done
     ];
}


// As sender, acknowledge a "failed" delivery
- (void) outDeliveryAcknowledgeFailed: (NSString*)messageId withReceiverId:(NSString*)receiverId onReady:(DoneBlock)done {
    [self outDeliveryAcknowledgeMethod:@"outDeliveryAcknowledgeFailed"
                     withExpectedState:kDeliveryStateFailedAcknowledged
                         withMessageId:messageId
                        withReceiverId:receiverId
                               onReady:done
     ];
}

// As sender, acknowledge a "rejected" delivery
- (void) outDeliveryAcknowledgeRejected: (NSString*)messageId withReceiverId:(NSString*)receiverId onReady:(DoneBlock)done {
    [self outDeliveryAcknowledgeMethod:@"outDeliveryAcknowledgeRejected"
                     withExpectedState:kDeliveryStateRejectedAcknowledged
                         withMessageId:messageId
                        withReceiverId:receiverId
                               onReady:done
     ];
}

// abort a delivery as sender
//TalkDelivery outDeliveryAbort(String messageId, String recipientId);
- (void) outDeliveryAbort: (NSString*) theMessageId forClient:(NSString*) theReceiverClientId onReady:(DoneBlock)done {
    // NSLog(@"deliveryAbort: %@", delivery);
    [_serverConnection invoke: @"outDeliveryAbort" withParams: @[theMessageId, theReceiverClientId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSDictionary * result = responseOrError;
             NSString * resultState = result[@"state"];
             if (![kDeliveryStateAborted isEqualToString:resultState] && ![kDeliveryStateAbortedAcknowledged isEqualToString:resultState]) {
                 NSLog(@"ERROR: outDeliveryAbort() returned bad state %@", responseOrError);
             } else {
                 [self outgoingDeliveryUpdated:@[responseOrError] isResult:YES onDone:done];
             }
             // NSLog(@"outDeliveryAbort() returned delivery: %@", responseOrError);
         } else {
             NSLog(@"outDeliveryAbort() failed: %@", responseOrError);
         }
     }];
}

// tell that a delivery is unknown to you as sender
//void outDeliveryUnknown(String messageId, String recipientId);
- (void) outDeliveryUnknown: (NSString*) theMessageId forClient:(NSString*) theReceiverClientId onReady:(DoneBlock)done {
    // NSLog(@"deliveryAbort: %@", delivery);
    [_serverConnection invoke: @"outDeliveryUnknown" withParams: @[theMessageId, theReceiverClientId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"outDeliveryUnknown() repsonse ok");
         } else {
             NSLog(@"outDeliveryUnknown() failed: %@", responseOrError);
         }
     }];
}

// tell that a delivery is unknown to you as receiver
//void outDeliveryUnknown(String messageId, String recipientId);
- (void) inDeliveryUnknown: (NSString*) theMessageId onReady:(DoneBlock)done {
    // NSLog(@"deliveryAbort: %@", delivery);
    [_serverConnection invoke: @"inDeliveryUnknown" withParams: @[theMessageId]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSLog(@"inDeliveryUnknown() repsonse ok");
         } else {
             NSLog(@"inDeliveryUnknown() failed: %@", responseOrError);
         }
     }];
}



// reject a delivery as receiver
// shoould be called when something is fishy with a message
// TalkDelivery inDeliveryReject(String messageId, String reason);
- (void) inDeliveryReject: (NSString*) theMessageId withReason:(NSString*) theReason {
    // NSLog(@"deliveryAbort: %@", delivery);
    [_serverConnection invoke: @"inDeliveryReject" withParams: @[theMessageId, theReason]
                   onResponse: ^(id responseOrError, BOOL success)
     {
         if (success) {
             NSDictionary * result = responseOrError;
             NSString * resultState = result[@"state"];
             if (![kDeliveryStateRejected isEqualToString:resultState]) {
                 NSLog(@"ERROR: inDeliveryReject() returned bad state %@", responseOrError);
             }
             HXOMessage * message = [self getMessageById:theMessageId inContext:self.delegate.mainObjectContext];
             Delivery * delivery = message.deliveries.anyObject;
             
             if (delivery != nil) {
                 [AppDelegate.instance deleteObject:delivery.message];
             }

             // NSLog(@"inDeliveryReject() returned delivery: %@", responseOrError);
         } else {
             NSLog(@"inDeliveryReject() failed: %@", responseOrError);
         }
     }];
}

#pragma mark - Attachment transfer signaling rpc


- (void) callAttachmentStateChangeMethod:(NSString *)method withFileId:(NSString*) fileId withhandler:(StringResultHandler)handler{
    
    [_serverConnection invoke: method withParams: @[fileId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"%@() got result: %@", method, responseOrError);
            if (handler) handler(responseOrError, YES);
        } else {
            NSLog(@"%@(fileId=%@) failed: %@", method, fileId, responseOrError);
            if (handler) handler(responseOrError, NO);
        }
    }];
}

- (void) callAttachmentStateChangeMethod:(NSString *)method withFileId:(NSString*) fileId forReceiver:(NSString*)receiverId withhandler:(StringResultHandler)handler{
    
    [_serverConnection invoke: method withParams: @[fileId, receiverId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"%@() got result: %@", method, responseOrError);
            if (handler) handler(responseOrError, YES);
        } else {
            NSLog(@"%@(fileId=%@,receiverId=%@) failed: %@", method, fileId, receiverId, responseOrError);
            if (handler) handler(responseOrError, NO);
        }
    }];
}


// should be called by the receiver of an transfer file after download; the server can the delete the file in case
//String receivedFile(String fileId);
- (void) receivedFile:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"receivedFile" withFileId:fileId withhandler:handler];
}

// should be called by the receiver of an transfer file if the user has aborted the download
//String abortedFileDownload(String fileId);
- (void) abortedFileDownload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"abortedFileDownload" withFileId:fileId withhandler:handler];
}
// should be called by the receiver of an transfer file if the client has exceeded the download retry count
//String failedFileDownload(String fileId);
- (void) failedFileDownload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"failedFileDownload" withFileId:fileId withhandler:handler];
}
// should be called by the receiver of an transfer file when a final attachment sender set state has been seen
//String acknowledgeAbortedFileUpload(String fileId);
- (void) acknowledgeAbortedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"acknowledgeAbortedFileUpload" withFileId:fileId withhandler:handler];
}
//String acknowledgeFailedFileUpload(String fileId);
- (void) acknowledgeFailedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"acknowledgeFailedFileUpload" withFileId:fileId withhandler:handler];
}

//------ sender attachment state indication methods
// should be called by the sender of an transfer file after upload has been started
//String startedFileUpload(String fileId);
- (void) startedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"startedFileUpload" withFileId:fileId withhandler:handler];
}
// should be called by the sender of an transfer file when the upload has been paused
//String pausedFileUpload(String fileId);
- (void) pausedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"pausedFileUpload" withFileId:fileId withhandler:handler];
}
// should be called by the sender of an transfer file after upload has been finished
//String finishedFileUpload(String fileId);
- (void) finishedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"finishedFileUpload" withFileId:fileId withhandler:handler];
}
// should be called by the sender of an transfer file when the upload is aborted by the user
//String abortedFileUpload(String fileId);
- (void) abortedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"abortedFileUpload" withFileId:fileId withhandler:handler];
}
// should be called by the sender of an transfer file when upload retry count has been exceeded
//String failedFileUpload(String fileId);
- (void) failedFileUpload:(NSString*)fileId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"failedFileUpload" withFileId:fileId withhandler:handler];
}
// should be called by the sender of an transfer file when a final attachment receiver set state has been seen
//String acknowledgeReceivedFile(String fileId);
- (void) acknowledgeReceivedFile:(NSString*)fileId forReceiver:(NSString*)receiverId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"acknowledgeReceivedFile" withFileId:fileId forReceiver:receiverId withhandler:handler];
}
//String acknowledgeAbortedFileDownload(String fileId);
- (void) acknowledgeAbortedFileDownload:(NSString*)fileId forReceiver:(NSString*)receiverId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"acknowledgeAbortedFileDownload" withFileId:fileId forReceiver:receiverId withhandler:handler];
}
//String acknowledgeFailedFileDownload(String fileId);
- (void) acknowledgeFailedFileDownload:(NSString*)fileId forReceiver:(NSString*)receiverId withhandler:(StringResultHandler)handler{
    [self callAttachmentStateChangeMethod:@"acknowledgeFailedFileDownload" withFileId:fileId forReceiver:receiverId withhandler:handler];
}


- (void) updatePresence: (NSString*) clientName
             withStatus: (NSString*) clientStatus
             withAvatar: (NSString*)avatarURL
                withKey: (NSData*) keyId
   withConnectionStatus: (NSString*) clientConnectionStatus
                handler:(GenericResultHandler)handler
{
    if (keyId == nil) {
        NSLog(@"updatePresence() failed: keyId is nil");
        handler(NO);
        return;
    }
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
        myConnectionStatus = kPresenceStateOnline;
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
    if (![kPresenceStateOnline isEqualToString:[UserProfile sharedProfile].connectionStatus]) {
        [UserProfile sharedProfile].connectionStatus=kPresenceStateOnline;
        [self modifyPresenceConnectionStatusWithHandler:nil];
    }
}

- (void) changePresenceToTyping {
    if (![kPresenceStateTyping isEqualToString:[UserProfile sharedProfile].connectionStatus]) {
        [UserProfile sharedProfile].connectionStatus=kPresenceStateTyping;
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
    if (myKeyBits == nil) {
#if 0
        ModalTaskHUD * hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"key_renewal_hud_title", nil)];
        [hud show];
        [UserProfile.sharedProfile renewKeypairWithSize: kHXODefaultKeySize completion: ^(BOOL success){
            [hud dismiss];
            if (success) {
                NSData * myKeyBits = [[UserProfile sharedProfile] publicKey];
                [self verifyKey:myKeyBits handler:handler];
            } else {
                handler(NO,NO);
            }
        }];
#else
        NSLog(@"#ERROR: verifyKeyWithHandler failed, no public key");
        handler(NO,NO);
#endif
    } else {
        [self verifyKey:myKeyBits handler:handler];
    }
}

- (void) registerApns: (NSString*) token {
    // NSLog(@"registerApns: %@", token);
    [_serverConnection invoke: @"registerApns" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"registerApns(): got result: %@", responseOrError);
            [self setApnsMode];
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

- (void) setApnsMode: (NSString*) mode {
    // NSLog(@"setApnsMode: %@", mode);
    [_serverConnection invoke: @"setApnsMode" withParams: @[mode] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            // NSLog(@"registerApns(): got result: %@", responseOrError);
        } else {
            // TODO retry?
            NSLog(@"setApnsMode(): failed: %@", responseOrError);
        }
    }];
}

- (void) setApnsMode {
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOAnonymousNotifications]) {
        [self setApnsMode:@"default"];
    } else {
        [self setApnsMode:@"background"];
    }
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
        [self.delegate didPairWithStatus: success];
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

//void setGroupNotifications(String groupId, String preference);
- (void) setGroupNotifications:(NSString*)groupId withPreference:(NSString*)preference handler: (GenericResultHandler) handler {
    //NSLog(@"setGroupNotifications");
    [_serverConnection invoke: @"setGroupNotifications" withParams: @[groupId, preference] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}

//void setClientNotifications(String otherClientId, String preference);
- (void) setClientNotifications:(NSString*)otherClientId withPreference:(NSString*)preference handler: (GenericResultHandler) handler {
    //NSLog(@"setClientNotifications");
    [_serverConnection invoke: @"setClientNotifications" withParams: @[otherClientId, preference] onResponse: ^(id responseOrError, BOOL success) {
        handler(success);
    }];
}


#pragma mark - Incoming RPC Calls

-(void)deliveriesReady {
    NSLog(@"deliveriesReady");
    if (self.delegate.processingBackgroundNotification) {
        [self.delegate finishBackgroundNotificationProcessing];
    }
}

- (void) incomingDelivery: (NSArray*) params {
    if (params.count != 2) {
        NSLog(@"incomingDelivery requires an array of two parameters (delivery, message), but got %d parameters.", (int)params.count);
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

- (void) incomingDeliveryUpdated: (NSArray*) params {
    if (params.count != 1) {
        NSLog(@"incomingDelivery one parameter (delivery), but got %d parameters.", (int)params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"incomingDelivery: parameter 0 must be a NSDictionary");
        return;
    }
    NSDictionary * deliveryDict = params[0];
    
    if (USE_VALIDATOR) [self validateObject: deliveryDict forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
    NSString * messageId = deliveryDict[@"messageId"];
    NSString * receiverId = deliveryDict[@"receiverId"];
    
    if (messageId == nil || receiverId == nil) {
        NSLog(@"#ERROR: incomingDeliveryUpdated: delivery has not message or receiver id");
        return;
    }
   // NSString * lockId = [self chatLockForSenderId:senderId andGroupId:groupId];
    
    // [self.delegate performWithLockingId:messageId inNewBackgroundContext:^(NSManagedObjectContext *context) {
    [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
        HXOMessage * message = [self getMessageById:messageId inContext:context];
        if (message == nil) {
            NSLog(@"#ERROR: incomingDeliveryUpdated: message with id %@ not found",messageId);
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self inDeliveryUnknown:messageId onReady:^{}];
            }];
            return;
        }
        Delivery * delivery = message.deliveries.anyObject;
        if (delivery == nil) {
            NSLog(@"#ERROR: incomingDeliveryUpdated: no delivery attached to message");
            return;
        }
        
        //[delivery updateStatesWithDictionary:deliveryDict];
        [delivery updateWithDictionary:deliveryDict withKeys:[Delivery minimumUpdateRpcKeys]];
        
        if (delivery.message.attachment != nil) {
            NSString * fileId = delivery.message.attachmentFileId;
            if ([kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED isEqualToString:delivery.attachmentState]) {
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    [self acknowledgeFailedFileUpload:fileId withhandler:^(NSString *result, BOOL ok) {
                    }];
                    // TODO: update UI
                }];
            }
            if ([kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED isEqualToString:delivery.attachmentState]) {
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    [self acknowledgeAbortedFileUpload:fileId withhandler:^(NSString *result, BOOL ok) {
                    }];
                    // TODO: update UI
                }];
            }
            if ([kDelivery_ATTACHMENT_STATE_UPLOADING isEqualToString:delivery.attachmentState] ||
                [kDelivery_ATTACHMENT_STATE_UPLOADED isEqualToString:delivery.attachmentState]) {
                [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[delivery.message.attachment]
                                                                            withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)
                {
                    Attachment * attachment = (Attachment*)managedObjects[0];
                    if (attachment.downloadable) {
                        [self enqueueDownloadOfAttachment:attachment];
                    }
                    [self updateAttachmentInDeliveryStateIfNecessary:attachment];
                }];
            }
        }
        //[self.delegate saveContext:context];
    }];
}

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

-(Delivery *) getDeliveryByMessageIdAndReceiverId:(NSString *) theMessageId withReceiver: (NSString *) theReceiverId inContext:(NSManagedObjectContext*)context {
    NSDictionary * vars = @{ @"messageId" : theMessageId,
                             @"receiverId" : theReceiverId};
    if (DELIVERY_TRACE) NSLog(@"getDeliveryByMessageIdAndReceiverId vars = %@", vars);
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"DeliveryByMessageIdAndReceiverId" substitutionVariables: vars];
    NSError *error;
    NSArray *deliveries = [context executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"getDeliveryByMessageIdAndReceiverId: Fetch request failed: %@", error);
        abort();
    }
    Delivery * delivery = nil;
    if (deliveries.count > 0) {
        delivery = deliveries[0];
        if (deliveries.count > 1) {
            NSLog(@"WARNING: Multiple deliveries with MessageId %@ for receiver %@ found", theMessageId, theReceiverId);
        }
    } else {
        if (DELIVERY_TRACE) NSLog(@"Delivery with MessageId %@ for receiver %@ not in deliveries", theMessageId, theReceiverId);
    }
    return delivery;
}


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

-(Delivery *) getDeliveryByMessageTagAndGroupIdAndReceiverId:(NSString *) theMessageTag withGroupId: (NSString *) theGroupId  withReceiverId:(NSString*) receiverId inContext:(NSManagedObjectContext*)context{
    NSDictionary * vars = @{ @"messageTag" : theMessageTag,
                             @"groupId" : theGroupId,
                             @"receiverId" : receiverId};
    if (DELIVERY_TRACE) NSLog(@"getDeliveryByMessageTagAndGroupIdAndReceiverId vars = %@", vars);
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

-(Delivery *) getDeliveryByAttachmentFileIdAndReceiverId:(NSString *) theFileId withReceiver: (NSString *) theReceiverId inContext:(NSManagedObjectContext*)context {
    NSDictionary * vars = @{ @"attachmentFileId" : theFileId,
                             @"receiverId" : theReceiverId};
    if (DELIVERY_TRACE) NSLog(@"getDeliveryByAttachmentFileIdAndReceiverId vars = %@", vars);
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"DeliveryByAttachmentFileIdAndReceiverId" substitutionVariables: vars];
    NSError *error;
    NSArray *deliveries = [context executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"getDeliveryByAttachmentFileIdAndReceiverId: Fetch request failed: %@", error);
        abort();
    }
    Delivery * delivery = nil;
    if (deliveries.count > 0) {
        delivery = deliveries[0];
        if (deliveries.count > 1) {
            NSLog(@"WARNING: Multiple deliveries with attachmentFileId %@ for receiver %@ found", theFileId, theReceiverId);
        }
    } else {
        if (DELIVERY_TRACE) NSLog(@"Delivery with attachmentFileId %@ for receiver %@ not in deliveries", theFileId, theReceiverId);
    }
    return delivery;
}

- (void) outDeliveryAcknowledgeState:(NSString*)state withMessageId:(NSString*)messageId withReceiverId:(NSString*)receiverId {

    NSString * updateKey = [NSString stringWithFormat:@"ack-%@-%@", messageId, receiverId];
    
    if ([_pendingDeliveryUpdates containsObject:updateKey]) {
        return;
    }
    
    if ([Delivery shouldAcknowledgeStateForOutgoing:state]) {
        [_pendingDeliveryUpdates addObject:updateKey];
        if ([kDeliveryStateDeliveredUnseen isEqualToString:state]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [SoundEffectPlayer messageDelivered];
                [self outDeliveryAcknowledgeUnseen: messageId withReceiverId:receiverId onReady:^{
                    [_pendingDeliveryUpdates removeObject:updateKey];
                }];
            }];
        } else if ([kDeliveryStateDeliveredSeen isEqualToString:state]) {
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    [SoundEffectPlayer messageDelivered];
                    [self outDeliveryAcknowledgeSeen: messageId withReceiverId:receiverId onReady:^{
                        [_pendingDeliveryUpdates removeObject:updateKey];
                    }];
                }];
        } else if ([kDeliveryStateDeliveredPrivate isEqualToString:state]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [SoundEffectPlayer messageDelivered];
                [self outDeliveryAcknowledgePrivate: messageId withReceiverId:receiverId onReady:^{
                    [_pendingDeliveryUpdates removeObject:updateKey];
                }];
            }];
        } else if ([kDeliveryStateFailed isEqualToString:state]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self outDeliveryAcknowledgeFailed: messageId withReceiverId:receiverId onReady:^{
                    [_pendingDeliveryUpdates removeObject:updateKey];
                }];
            }];
        } else if ([kDeliveryStateRejected isEqualToString:state]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self outDeliveryAcknowledgeRejected: messageId withReceiverId:receiverId onReady:^{
                    [_pendingDeliveryUpdates removeObject:updateKey];
                }];
            }];
        } else {
            [_pendingDeliveryUpdates removeObject:updateKey];
        }
    }
}

- (void) outDeliveryAcknowledgeAttachmentState:(NSString*)attachmentState withFileId:(NSString*)myFileId forReceiver:(NSString*)receiverId withHandler:(StringResultHandler) handler{
    if ([Delivery shouldAcknowledgeAttachmentStateForOutgoing:attachmentState]) {
        if ([kDelivery_ATTACHMENT_STATE_RECEIVED isEqualToString:attachmentState]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                Delivery * delivery = [self getDeliveryByAttachmentFileIdAndReceiverId:myFileId withReceiver:receiverId inContext:context];
                NSLog(@"outDeliveryAcknowledgeAttachmentState: acknowledge delivery in state '%@'", delivery.attachmentState);
 //               if ([kDelivery_ATTACHMENT_STATE_RECEIVED isEqualToString:delivery.attachmentState] ||
 //                   [kDelivery_ATTACHMENT_STATE_RECEIVED_ACKNOWLEDGED isEqualToString:delivery.attachmentState]) {
                    [self acknowledgeReceivedFile: myFileId forReceiver:receiverId withhandler:handler];
 //               }
            }];
        } else if ([kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED isEqualToString:attachmentState]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self acknowledgeFailedFileDownload: myFileId forReceiver:receiverId withhandler:handler];
            }];
        } else if ([kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED isEqualToString:attachmentState]) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                [self acknowledgeAbortedFileDownload: myFileId forReceiver:receiverId withhandler:handler];
            }];
        }
    }
}

- (void) outDeliveryAcknowledgeAttachmentState:(NSString*)attachmentState forDelivery:(Delivery*)myDelivery withFileId:(NSString*)myFileId forReceiver:(NSString*)receiverId {
    
    NSArray * myObjIds = permanentObjectIds(@[myDelivery]);
    if (myObjIds == nil) {
        NSLog(@"outDeliveryAcknowledgeAttachmentState: can not obtain permanent id for delivery, not acknowledging");
        return;
    }
    [self outDeliveryAcknowledgeAttachmentState:attachmentState
                                     withFileId:myFileId
                                    forReceiver:receiverId
                                    withHandler:^(NSString *result, BOOL ok)
     {
         [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
             NSArray * myObjects = existingManagedObjects(myObjIds, context);
             if (myObjects == nil) {
                 NSLog(@"outDeliveryAcknowledgeAttachmentState: can not obtain existing object for delivery, not processing result");
                 return;
             }
             Delivery * myDelivery = (Delivery *)myObjects[0];
             if (DELIVERY_TRACE) NSLog(@"outDeliveryAcknowledgeAttachmentState returned %@ type %@", result, result.class);
             if (ok) {
                 myDelivery.attachmentState = result;
             } else {
                 // it might happen that a delivery is gone on the server, but we still have it
                 // in these cases we will get an error with result code 0 and set the attachment delivery state to unknown so
                 // we do not try to confirm it again and again on startup
                 if ([result isKindOfClass:[NSDictionary class]]) {
                     NSDictionary * myDict = (NSDictionary*)result;
                     NSNumber * errorCode = myDict[@"code"];
                     if (errorCode != nil && errorCode.intValue == 0) {
                         NSLog(@"outDeliveryAcknowledgeAttachmentState: setting attachmentState to 'unknown'");
                         myDelivery.attachmentState = @"unknown";
                     }
                 }
             }
         }];
     }];
}

// called by server to notify us about status changes of outgoing deliveries we made
- (void) outgoingDeliveryUpdated: (NSArray*) params {
    [self outgoingDeliveryUpdated:params isResult:NO onDone:nil];
}


- (void) outgoingDeliveryUpdated: (NSArray*) params isResult:(BOOL)isResult onDone:(DoneBlock)done {
        if (params.count != 1) {
            NSLog(@"outgoingDeliveryUpdated: requires an array of one parameter (delivery), but got %d parameters.", (int)params.count);
            if (done != nil) done();
            return;
        }
        if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
            NSLog(@"outgoingDeliveryUpdated: argument is not a valid object");
            if (done != nil) done();
            return;
        }
        NSDictionary * deliveryDict = params[0];
        //NSLog(@"outgoingDelivery() called, dict = %@", deliveryDict);
        
    NSString * myMessageId = deliveryDict[@"messageId"];
    
    if (myMessageId == nil) {
        NSLog(@"#ERROR:outgoingDeliveryUpdated: missing messageId");
        if (done != nil) done();
        return;
    }
    
    //NSString * groupId = deliveryDict[@"groupId"];
    //NSString * senderId = deliveryDict[@"senderId"];

    // we need to log all message in chat to avoid timeSection problems
    // (when acceptedTime is set, the timesection of other messages will be touched, too)
    //NSString * lockId = [self chatLockForSenderId:senderId andGroupId:groupId];
    
    //[self.delegate performWithLockingId:lockId inNewBackgroundContext:^(NSManagedObjectContext *context) {
    [self.delegate performWithLockingId:kqMessaging inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        NSString * myMessageTag = deliveryDict[@"messageTag"];
        NSString * myReceiverId = deliveryDict[@"receiverId"];
        NSString * myGroupId = deliveryDict[@"groupId"];
        if (USE_VALIDATOR) [self validateObject: deliveryDict forEntity:@"RPC_TalkDelivery_in"];  // TODO: Handle Validation Error
        
        Delivery * myDelivery = nil;
        if (myGroupId) {
            if (myReceiverId != nil && myReceiverId.length > 0) {
                myDelivery = [self getDeliveryByMessageTagAndGroupIdAndReceiverId:myMessageTag withGroupId: myGroupId withReceiverId:myReceiverId inContext:context];
            } else {
                myDelivery = [self getDeliveryByMessageTagAndGroupId:myMessageTag withGroupId: myGroupId inContext:context];
            }
        } else {
            if (myReceiverId !=nil) {
                myDelivery = [self getDeliveryByMessageTagAndReceiverId:myMessageTag withReceiver: myReceiverId inContext:context];
            } else {
                NSLog(@"#ERROR: outgoingDeliveryUpdated: missing receiverId and groupId in delivery %@", deliveryDict);
                if (done != nil) {
                    [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                        done();
                    }];
                }
                return;
            }
        }
        if (DELIVERY_TRACE) NSLog(@"myDelivery: message Id: %@ receiver:%@ group:%@ objId:%@",myDelivery.message.messageId, myDelivery.receiver.clientId, myDelivery.group.clientId, myDelivery.objectID);
        
        HXOMessage * myMessage = [self getMessageByTag:myMessageTag inContext:context];
        
        if (DELIVERY_TRACE) NSLog(@"myMessage: message Id: %@ tag:%@ sender:%@ deliveries:%d",myMessage.messageId, myMessage.messageTag, myMessage.senderId, (int)myMessage.deliveries.count);
        
        if (myDelivery != nil && myMessage != nil) {
             /*
            if (myDelivery.isInFinalState && !isResult) {
                NSLog(@"#WARNING: outgoingDeliveryUpdated: outdated Notification received for delivery already in final state '%@', attachmentState '%@', messageId: %@",
                      myDelivery.state, myDelivery.attachmentState, deliveryDict[@"messageId"]);
                
                // acknowledge the state again just to satisfy the server although we already have received a newer state
                if (![Delivery isAcknowledgedState:deliveryDict[@"state"]]) {
                    [self outDeliveryAcknowledgeState:deliveryDict[@"state"] withMessageId:myMessageId withReceiverId:myReceiverId];
                }
                if (![Delivery isAcknowledgedAttachmentState:deliveryDict[@"attachmentState"]]) {
                    [self outDeliveryAcknowledgeAttachmentState:deliveryDict[@"attachmentState"] forDelivery:myDelivery withFileId:myMessage.attachmentFileId forReceiver:myReceiverId];
                }
                if (done != nil) {
                    [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                        done();
                    }];
                }
                return;
            }
             */
            if ([myDelivery.state isEqualToString:deliveryDict[@"state"]] && [myDelivery.attachmentState isEqualToString:deliveryDict[@"attachmentState"]]) {
                NSLog(@"#WARNING: outgoingDelivery notification received with unchanged state '%@', attachmentState '%@', messageId: %@",
                      myDelivery.state, myDelivery.attachmentState, deliveryDict[@"messageId"]);
            }
            if (DELIVERY_TRACE) {NSLog(@"outgoingDelivery Notification: Delivery state '%@'->'%@' attachmentState '%@'->'%@'for messageTag %@ id %@",myDelivery.state, deliveryDict[@"state"], myDelivery.attachmentState, deliveryDict[@"attachmentState"],myMessageTag, deliveryDict[@"messageId"]);}
            
            //[myDelivery updateWithDictionary: deliveryDict];
            [myDelivery updateWithDictionary:deliveryDict withKeys:[Delivery minimumUpdateRpcKeys]];

            [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[myDelivery.message]
                                                                        withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)
             {
                 [context refreshObject: managedObjects[0] mergeChanges: YES];
             }];
            
            if (!myDelivery.isFailure) {
                // start upload if message has not failed
                if ([kDelivery_ATTACHMENT_STATE_NEW isEqualToString: myDelivery.attachmentState]) {
                    [self.delegate performAfterCurrentContextFinishedInMainContextPassing:@[myDelivery.message.attachment]
                        withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects)
                    {
                        Attachment * attachment = managedObjects[0];
                        [self enqueueUploadOfAttachment:attachment];
                        [self checkUploadQueue];
                    }];
                }
            }
            
            if ([myDelivery isInMoreAdvancedStateThan:deliveryDict[@"state"]]) {
                // acknowledge incoming outdated state
                if (![Delivery isAcknowledgedState:deliveryDict[@"state"]]) {
                    [self outDeliveryAcknowledgeState:deliveryDict[@"state"] withMessageId:myMessageId withReceiverId:myReceiverId];
                }
            } else {
                [self outDeliveryAcknowledgeState:myDelivery.state withMessageId:myMessageId withReceiverId:myReceiverId];
            }
            
            if ([myDelivery isInMoreAdvancedAttachmentStateThan:deliveryDict[@"attachmentState"]]) {
                // acknowledge incoming outdated attachment state
                if (![Delivery isAcknowledgedAttachmentState:deliveryDict[@"attachmentState"]]) {
                    [self outDeliveryAcknowledgeAttachmentState:deliveryDict[@"attachmentState"] forDelivery:myDelivery withFileId:myMessage.attachmentFileId forReceiver:myReceiverId];
                }
            } else {
                [self outDeliveryAcknowledgeAttachmentState:myDelivery.attachmentState forDelivery:myDelivery withFileId:myMessage.attachmentFileId forReceiver:myReceiverId];
            }
            
        } else {
            // Can't remember delivery, probably database was nuked since, and we have not way to indicate succesful delivery to the user,
            // so we just acknowledge or abort if we can
            
            NSLog(@"#WARNING, outgoing message or delivery not found, myMessageId=%@, myReceiverId=%@", myMessageId, myReceiverId);
            
            if (myMessageId == nil || myReceiverId == nil) {
                NSLog(@"#WARNING, myMessageId or myReceiverId is nil, myMessageId=%@, myReceiverId=%@", myMessageId, myReceiverId);
            } else {
                [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                    [self outDeliveryUnknown:myMessageId forClient:myReceiverId onReady:^{
                    }];
                }];
            }
        }
        if (done != nil) {
            [self.delegate performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                done();
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
        [self presenceUpdatedInBackground:presence];
    }
}

- (void) presenceModifiedNotification: (NSArray*) params {
    //TODO: Error checking
    for (id presence in params) {
        // NSLog(@"presenceModifiedNotification presence=%@",presence);
        [self presenceModifiedInBackground:presence];
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
    if (CONNECTION_TRACE) NSLog(@"webSocket didCloseWithCode %d reason: %@ clean: %d", (int)code, reason, wasClean);
    _uncleanConnectionShutdown = code != 0 || [_serverConnection numberOfOpenRequests] !=0 || [_serverConnection numberOfFlushedRequests] != 0;
    if (CONNECTION_TRACE) NSLog(@"webSocket didCloseWithCode _uncleanConnectionShutdown = %d, openRequests = %d, flushedRequests = %d", _uncleanConnectionShutdown, [_serverConnection numberOfOpenRequests], [_serverConnection numberOfFlushedRequests]);
    BackendState oldState = _state;
    if (oldState == kBackendDisabling) {
        [self setState: kBackendDisabled];
    } else {
        [self setState: kBackendStopped];
    }
    if (oldState == kBackendStopping || oldState == kBackendDisabling) {
        [self cancelStateNotificationDelayTimer];
        if ([self.delegate respondsToSelector:@selector(backendDidStop)]) {
            [self.delegate backendDidStop];
        }
    } else {
        [self reconnect];
    }
}

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@ %d", error, (int)error.code);
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

-(void)makeSureAvatarUploadedForGroup:(Group*)group withCompletion:(CompletionBlock)completion {
    [self.delegate assertMainContext];
    if ([group iAmAdmin]) {
        NSData * myAvatarData = group.avatar;
        if (myAvatarData != nil && myAvatarData.length>0) {
            NSString * myCurrentAvatarURL = group.avatarURL;
            NSString * myCurrentAvatarUploadURL = group.avatarUploadURL;
            if (myCurrentAvatarURL != nil && myCurrentAvatarURL.length > 0) {
                if (myCurrentAvatarUploadURL != nil && myCurrentAvatarUploadURL.length > 0) {
                    [HXOBackend checkUploadStatus:myCurrentAvatarUploadURL hasSize:myAvatarData.length withCompletion:^(NSString *url, long long transferedSize, BOOL ok) {
                        if (!ok) {
                            group.avatarURL = @"";
                            [self uploadAvatarIfNeededForGroup:group withCompletion:^(NSError *theError) {
                                NSLog(@"#ERROR: makeSureAvatarUploadedForGroup group %@ done, error=%@", group.nickName, theError);
                                completion(theError);
                            }];
                            return;
                        }
                        completion(nil);
                    }];
                    return;
                }
            }
        }
    }
    completion(nil);
}


- (void) uploadAvatarIfNeededForGroup:(Group*)group withCompletion:(CompletionBlock)completion{
    [self.delegate assertMainContext];
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
    [self.delegate assertMainContext];
    if (CONNECTION_TRACE) {NSLog(@"uploadAvatar size %@ uploadURL=%@, downloadURL=%@", @(avatar.length), toURL, downloadURL );}
    
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
                              NSLog(@"uploadAvatar got response status = %d,(%@) headers=%@", (int)response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"uploadAvatar response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode == 301 || response.statusCode == 308 || response.statusCode == 200) {
                              if (CONNECTION_TRACE) {NSLog(@"uploadAvatar: seems ok, lets check");}
                              [HXOBackend checkUploadStatus:toURL hasSize:avatar.length withCompletion:^(NSString *url, long long transferedSize, BOOL ok) {
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
                              NSString * myDescription = [NSString stringWithFormat:@"uploadAvatar irregular response status = %d, headers=%@", (int)response.statusCode, response.allHeaderFields];
                              // NSLog(@"%@", myDescription);
                              NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.avatar.upload" code: 945 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                              handler(myError);
                          }
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"uploadAvatar error response status = %d, headers=%@, error=%@", (int)response.statusCode, response.allHeaderFields, error);
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
                              NSLog(@"downloadDataFromURL got response status = %d,(%@) headers=%@", (int)response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"downloadDataFromURL response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode == 200) {
                              if (CONNECTION_TRACE) {NSLog(@"downloadDataFromURL: response 200 ok");}
                              if (data == nil || data.length == 0) {
                                  NSLog(@"#WARNING: downloadDataFromURL: status ok, but response data ist empty, URL=%@", request.URL);
                              }
                              NSString * contentLength = response.allHeaderFields[@"Content-Length"];
                              if (contentLength != nil && [contentLength integerValue] != data.length) {
                                  NSString * myDescription = [NSString stringWithFormat:@"downloadDataFromURL content length mismatch, header Content-Lenght = %@, data length = %@, headers=%@", contentLength, @(data.length), response.allHeaderFields];
                                  // NSLog(@"%@", myDescription);
                                  NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.download" code: 931 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                                  handler(data, myError);
                              } else {
                                  handler(data,nil);
                              }
                              
                          } else {
                              NSString * myDescription = [NSString stringWithFormat:@"downloadDataFromURL irregular response status = %d, headers=%@", (int)response.statusCode, response.allHeaderFields];
                              // NSLog(@"%@", myDescription);
                              NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.download" code: 946 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                              handler(nil, myError);
                          }
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"downloadDataFromURL error response status = %d, headers=%@, error=%@", (int)response.statusCode, response.allHeaderFields, error);
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
    [self.delegate assertMainContext];
    NSData * myAvatarData = [UserProfile sharedProfile].avatar;
    if (myAvatarData != nil && myAvatarData.length>0) {
        NSString * myCurrentAvatarURL = [UserProfile sharedProfile].avatarURL;
        NSString * myCurrentAvatarUploadURL = [UserProfile sharedProfile].avatarUploadURL;
        if (myCurrentAvatarURL != nil && myCurrentAvatarURL.length > 0) {
            if (myCurrentAvatarUploadURL != nil && myCurrentAvatarUploadURL.length > 0) {
                [HXOBackend checkUploadStatus:myCurrentAvatarUploadURL hasSize:myAvatarData.length withCompletion:^(NSString *url, long long transferedSize, BOOL ok) {
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
    [self.delegate assertMainContext];
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
                            [HXOBackend checkUploadStatus:urls[@"uploadUrl"] hasSize:myAvatarData.length withCompletion:^(NSString *url, long long transferedSize, BOOL ok) {
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
                              @(theLength).stringValue, @"Content-Length",
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
                for (int i = 0; i < numCerts && !_pinnedCertFound; i++) {
                    SecCertificateRef cert = SecTrustGetCertificateAtIndex(secTrust, i);
                    NSData *certData = CFBridgingRelease(SecCertificateCopyData(cert));
                    
                    //NSLog(@"certData %d = %@", i, certData);
                    if (CHECK_CERTS_DEBUG) NSLog(@"Backend: connection: certData %d = len = %@", i, @(certData.length));
                    for (id ref in sslCerts) {
                        SecCertificateRef trustedCert = (__bridge SecCertificateRef)ref;
                        NSData *trustedCertData = CFBridgingRelease(SecCertificateCopyData(trustedCert));
                        
                        if (CHECK_CERTS_DEBUG) NSLog(@"Backend: connection: comparing with trustedCertData len %@", @(trustedCertData.length));
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

+ (void) checkUploadStatus:(NSString*)theURL hasSize:(long long)expectedSize withCompletion:(DataURLStatusHandler)handler {
    if (CHECK_URL_TRACE) {NSLog(@"checkUploadStatus uploadURL=%@, expectedSize=%lld", theURL, expectedSize );}
    
    theURL = [HXOBackend checkForceFilecacheUrl:theURL];
    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:theURL HTTPMethod:@"PUT" parameters:nil];
    NSDictionary * headers = @{@"Content-Length": @"0"};
    if (CHECK_URL_TRACE) {NSLog(@"checkUploadStatus: headers=%@", headers);}
	for (NSString *key in headers) {
		[request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
	}
	[request addValue:AppDelegate.instance.userAgent forHTTPHeaderField:@"User-Agent"];
    
    if (CHECK_URL_TRACE) {NSLog(@"checkUploadStatus: request header for check= %@",request.allHTTPHeaderFields);}
    GCHTTPRequestOperation *operation =
    [GCHTTPRequestOperation HTTPRequest:request
                          callBackQueue:nil
                      completionHandler:^(NSData *data, NSHTTPURLResponse *response) {
                          if (CHECK_URL_TRACE) {
                              NSLog(@"checkUploadStatus got response status = %d,(%@) headers=%@", (int)response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
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
                                          handler(theURL, rangeEnd+1, YES);
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
                                      NSLog(@"checkUploadStatus irregular Content-Length %@, response status = %d, headers=%@",ContentLength, (int)response.statusCode, response.allHeaderFields);
                                  }
                              }                              
                          } else {
                              NSLog(@"checkUploadStatus irregular response status = %d, headers=%@", (int)response.statusCode, response.allHeaderFields);
                          }
                          handler(theURL, -1, NO);
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"checkUploadStatus error response status = %d, headers=%@, error=%@", (int)response.statusCode, response.allHeaderFields, error);
                               handler(theURL, -1, NO);
                           }
                       challengeHandler:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                           [[HXOBackend instance] connection:connection willSendRequestForAuthenticationChallenge:challenge];
                       }
     ];
    [operation startRequest];
}


@end
