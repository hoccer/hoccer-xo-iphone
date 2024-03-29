//
//  HoccerXOBackend.h
//  HoccerXO
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JsonRpcWebSocket.h"

@class Contact;
@class Delivery;
@class HXOMessage;
@class Attachment;
@class AppDelegate;
@class Group;
@class GroupMembership;
@class GCNetworkQueue;
@class HXOEnvironment;

typedef void (^InviteTokenHanlder)(NSString*);
typedef void (^GenerateIdHandler)(NSString*);
typedef void (^SrpHanlder)(NSString*, NSDictionary * error);
typedef void (^RelationshipHandler)(NSArray*);
typedef void (^GroupsHandler)(NSArray*);
typedef void (^MembershipsHandler)(NSArray*);
typedef void (^PresenceHandler)(NSArray*);
typedef void (^GroupMembersOutdatedHandler)(NSArray*);
typedef void (^PublicKeyHandler)(NSDictionary*);
typedef void (^ObjectResultHandler)(NSDictionary*);
typedef void (^NumberResultHandler)(NSNumber* result);
typedef void (^HelloHandler)(NSDictionary*);
typedef void (^GenericResultHandler)(BOOL ok);
typedef void (^URLResultHandler)(NSURL * url);
typedef void (^StringResultHandler)(NSString* result, BOOL ok);
typedef void (^BoolResultHandler)(BOOL result, BOOL ok);
typedef void (^DataLoadedBlock)(NSData *, NSError*);
typedef void (^DoneBlock)();
typedef void (^GroupMemberDeleted)(GroupMembership* member);
typedef void (^GroupMemberChanged)(GroupMembership* member);
typedef void (^GroupHandler)(Group* group);
typedef void (^CreateGroupHandler)(Group* group);
typedef void (^FileURLRequestHandler)(NSDictionary* urls);
typedef void (^DataURLStatusHandler)(NSString * url, long long transferedSize, BOOL ok);
typedef void (^UpdateEnvironmentHandler)(NSString*);
typedef void (^DateHandler)(NSDate* date);
typedef void (^DeliveriesRequestCompletion)(NSArray* deliveries);
typedef void (^CompletionWithError)(NSError* theError);


@protocol HXODelegate <NSObject>

- (NSString*) apnDeviceToken;
//@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, nonatomic) NSManagedObjectModel *managedObjectModel;

- (void) didPairWithStatus: (BOOL) status; // pregnant...
-(void) didFailWithInvalidCertificate: (DoneBlock) done;

@optional

-(void) backendDidStop;

@end

@interface HXOBackend : NSObject <JsonRpcWebSocketDelegate>

@property (nonatomic, weak) AppDelegate * delegate;
@property (nonatomic, strong) NSURLConnection *avatarUploadConnection;

@property (nonatomic, strong) NSDate *latestKnownServerTime;
@property (nonatomic, strong) NSDate *latestKnownServerTimeAtClientTime;
@property (nonatomic) NSTimeInterval latestKnownServerTimeOffset;

@property (atomic, strong) NSString *connectionInfo;
@property (atomic, strong) NSDictionary * serverInfo;

@property (readonly, nonatomic) NSArray * certificates;

@property BOOL firstConnectionAfterCrashOrUpdate;
@property (readonly) BOOL isLoggedIn;


- (id) initWithDelegate: (AppDelegate *) theAppDelegate;

- (void) sendMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment withCompletion:(CompletionWithError)completion;
- (void) forwardMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment withCompletion:(CompletionWithError)completion;

- (void) inDeliveryConfirmPrivate: (NSString*) messageId withDelivery: (Delivery*) delivery;
- (void) inDeliveryConfirmSeen: (NSString*) messageId withDelivery: (Delivery*) delivery;
- (void) inDeliveryConfirmUnseen: (NSString*) messageId withDelivery: (Delivery*) delivery;
- (void)inDeliveryConfirmMessage:(HXOMessage *)message withDelivery:(Delivery *)delivery;

    //- (void) generateToken: (NSString*) purpose validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler;
- (void) generatePairingTokenWithHandler: (InviteTokenHanlder) handler;

- (void) pairByToken: (NSString*) token;
- (void) acceptInvitation: (NSString*) token;

- (void) createGroupWithHandler:(CreateGroupHandler)handler;
- (void) createGroupWithMembersAndType:(NSString*)type
                               withTag:(NSString*)groupTag
                              withName:(NSString*)groupName
                           withMembers:(NSArray*)memberIds
                             withRoles:(NSArray*)roles
                           withHandler:(CreateGroupHandler)handler;

- (void) inviteGroupMember:(Contact *)contact toGroup:(Group*)group onDone:(GenericResultHandler)doneHandler;
- (void) removeGroupMember:(GroupMembership *) member onDeletion:(GroupMemberDeleted)deletionHandler;
- (void) updateGroup:(Group *) group;

- (void) deleteGroup:(Group *) group onDeletion:(GroupHandler)handler;
- (void) joinGroup:(Group *) group onJoined:(GroupHandler)handler;
- (void) leaveGroup:(Group *) group onGroupLeft:(GroupHandler)handler;

- (void) inviteGroupMemberFailedForContact:(Contact*)contact inGroup:(Group*)group;
- (void) disinviteGroupMemberFailedForContact:(Contact*)contact inGroup:(Group*)group;

- (void) syncGroupsWithForce:(BOOL)forceAll withCompletion:(GenericResultHandler)completion;

- (void) hintApnsUnreadMessage: (NSUInteger) count handler: (GenericResultHandler) handler;

- (void) blockClient: (NSString*) clientId handler: (GenericResultHandler) handler;
- (void) unblockClient: (NSString*) clientId handler: (GenericResultHandler) handler;

- (void) depairClient: (NSString*) clientId handler: (GenericResultHandler) handler;

- (void) inviteFriend: (NSString*) clientId handler: (GenericResultHandler) handler;
- (void) disinviteFriend: (NSString*) clientId handler: (GenericResultHandler) handler;
- (void) acceptFriend: (NSString*) clientId handler: (GenericResultHandler) handler;
- (void) refuseFriend: (NSString*) clientId handler: (GenericResultHandler) handler;

- (void) setGroupNotifications:(NSString*)groupId withPreference:(NSString*)preference handler: (GenericResultHandler) handler;
- (void) setClientNotifications:(NSString*)otherClientId withPreference:(NSString*)preference handler: (GenericResultHandler) handler;

- (void) acceptFriendFailedAlertForContact:(Contact*)contact;
- (void) refuseFriendFailedAlertForContact:(Contact*)contact;
- (void) inviteFriendFailedAlertForContact:(Contact*)contact;
- (void) disinviteFriendFailedAlertForContact:(Contact*)contact;

- (void) gotAPNSDeviceToken: (NSString*) deviceToken;
- (void) unregisterApns;

- (void) modifyPresenceClientName: (NSString*) clientName handler:(GenericResultHandler)handler;
- (void) modifyPresenceClientStatus: (NSString*) clientStatus handler:(GenericResultHandler)handler;
- (void) modifyPresenceAvatarURL: (NSString*) avatarURL handler:(GenericResultHandler)handler;
- (void) modifyPresenceKeyId: (NSData*) keyId handler:(GenericResultHandler)handler;
- (void) modifyPresenceConnectionStatus: (NSString*) connectionStatus handler:(GenericResultHandler)handler;

// Call one of the following five function after one of the presence fields has been updated
- (void) modifyPresenceClientNameWithHandler:(GenericResultHandler)handler;
- (void) modifyPresenceClientStatusWithHandler:(GenericResultHandler)handler;
- (void) modifyPresenceAvatarURLWithHandler:(GenericResultHandler)handler;
- (void) modifyPresenceKeyIdWithHandler:(GenericResultHandler)handler;
- (void) modifyPresenceConnectionStatusWithHandler:(GenericResultHandler)handler;

- (void) changePresenceToTyping;
- (void) changePresenceToNormal;

- (void) start: (BOOL) performRegistration;
- (void) stop;

- (void)disable;
- (void)enable;

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;

- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

- (void) downloadFinished:(Attachment *)theAttachment;
- (void) uploadFinished:(Attachment *)theAttachment;
- (void) downloadFailed:(Attachment *)theAttachment;
- (void) uploadFailed:(Attachment *)theAttachment;
- (void) uploadStarted:(Attachment *)theAttachment;
- (void) uploadPaused:(Attachment *)theAttachment;

- (void) syncRelationshipsWithForce:(BOOL)forceAll withCompletion:(GenericResultHandler)completion;
- (void) updatePresenceWithHandler:(GenericResultHandler)handler;

- (void) updateKeyWithHandler:(GenericResultHandler) handler;
- (void)deleteAccountForReason:(NSString *)reason  handler:(GenericResultHandler)handler;


- (void) deleteInDatabaseAllMembersAndContactsofGroup:(Group*) group inContext:(NSManagedObjectContext*) context;
- (void) handleDeletionOfContact:(Contact*)contact withForce:(BOOL)force inContext:(NSManagedObjectContext*) context;
- (void) handleDeletionOfGroupMember:(GroupMembership*)myMember inGroup:(Group*)group withContact:(Contact*)memberContact disinvited:(BOOL)disinvited inContext:(NSManagedObjectContext*) context;


- (void) enqueueDownloadOfAttachment:(Attachment*) theAttachment;
- (void) enqueueUploadOfAttachment:(Attachment*) theAttachment;
- (void) dequeueDownloadOfAttachment:(Attachment*) theAttachment;
- (void) dequeueUploadOfAttachment:(Attachment*) theAttachment;
    
- (void) checkTransferQueues;
- (void)checkDowloadQueue;
- (void)checkUploadQueue;

- (GCNetworkQueue *)attachmentUploadQueue;
- (GCNetworkQueue *)attachmentDownloadQueue;

- (void) updateEnvironment:(HXOEnvironment *) environment withHandler:(UpdateEnvironmentHandler)handler;
- (void) destroyEnvironmentType:(NSString*)type withHandler:(GenericResultHandler)handler;

- (void) sendEnvironmentDestroyWithType:(NSString*)type;
- (void) sendEnvironmentUpdate;
- (NSString*) stateString;


- (NSDate*) estimatedServerTime;

-(Contact *) getContactByClientId:(NSString *) theClientId inContext:(NSManagedObjectContext *)context;
-(HXOMessage*) getMessageById:(NSString*)messageId inContext:(NSManagedObjectContext*) context;

+ (NSData *) calcKeyId:(NSData *) myKeyBits;
+ (NSString *) keyIdString:(NSData *) myKeyId;

+ (NSNumber*) millisFromDate:(NSDate *) date;
+ (NSDate*) dateFromMillis:(NSNumber*) milliSecondsSince1970;

+ (void)broadcastConnectionInfo;
+ (id) registerConnectionInfoObserverFor:(UIViewController*)controller;
+ (void)adjustTimeSectionsForMessage:(HXOMessage*) message;

+ (BOOL) allowUntrustedServerCertificate;
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;

- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                         payloadData:(NSData *)payload
                       payloadStream:(NSInputStream*)stream
                             headers:(NSDictionary *)headers;

+ (BOOL)scanRange:(NSString*)theRange rangeStart:(long long*)rangeStart rangeEnd:(long long*)rangeEnd contentLength:(long long*)contentLength;


+ (void) downloadDataFromURL:(NSString*)fromURL inQueue:(GCNetworkQueue*)queue withCompletion:(DataLoadedBlock)handler;
+ (HXOBackend*)instance;

+ (BOOL) isZeroData:(NSData*)theData;
+ (BOOL) isInvalid:(NSData*)theData;

+ (NSString*)checkForceFilecacheUrl:(NSString*)theURL;
+ (void) checkUploadStatus:(NSString*)theURL hasSize:(long long)expectedSize withCompletion:(DataURLStatusHandler)handler;

// messages >= sinceTime && < beforeTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalSinceTime:(NSDate *)sinceTime beforeTime:(NSDate*)beforeTime;

// messages > afterTime && <= untilTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalAfterTime:(NSDate *)afterTime untilTime:(NSDate*)untilTime;

// messages >= sinceTime && <= untilTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalSinceTime:(NSDate *)sinceTime untilTime:(NSDate*)untilTime;

// messages > afterTime && < beforeTime
+ (NSArray *) messagesByContact:(Contact*)contact inIntervalAfterTime:(NSDate *)afterTime beforeTime:(NSDate*)beforeTime;

@end
