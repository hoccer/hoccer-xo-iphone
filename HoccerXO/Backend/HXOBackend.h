//
//  HoccerXOBackend.h
//  HoccerXO
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HXOConfig.h"

#import "JsonRpcWebSocket.h"

@class Contact;
@class Delivery;
@class HXOMessage;
@class Attachment;
@class AppDelegate;
@class Group;
@class GroupMembership;
@class GCNetworkQueue;

typedef void (^InviteTokenHanlder)(NSString*);
typedef void (^GenerateIdHandler)(NSString*);
typedef void (^SrpHanlder)(NSString*);
typedef void (^RelationshipHandler)(NSArray*);
typedef void (^GroupsHandler)(NSArray*);
typedef void (^MembershipsHandler)(NSArray*);
typedef void (^PresenceHandler)(NSArray*);
typedef void (^PublicKeyHandler)(NSDictionary*);
typedef void (^HelloHandler)(NSDictionary*);
typedef void (^GenericResultHandler)(BOOL);
typedef void (^AttachmentCompletionBlock)(Attachment *, NSError*);
typedef void (^DataLoadedBlock)(NSData *, NSError*);
typedef void (^DoneBlock)();
typedef void (^GroupMemberDeleted)(GroupMembership* member);
typedef void (^GroupMemberChanged)(GroupMembership* member);
typedef void (^GroupHandler)(Group* group);
typedef void (^CreateGroupHandler)(Group* group);
typedef void (^FileURLRequestHandler)(NSDictionary* urls);

@protocol HXODelegate <NSObject>

- (NSString*) apnDeviceToken;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
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

@property (readonly, nonatomic) NSArray * certificates;

@property BOOL firstConnectionAfterCrashOrUpdate;

- (id) initWithDelegate: (AppDelegate *) theAppDelegate;

- (void) sendMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment;
- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary;
- (void) forwardMessage:(NSString *) text toContactOrGroup:(Contact*)contact toGroupMemberOnly:(Contact*)privateGroupMessageContact withAttachment: (Attachment*) attachment;
- (Attachment*) cloneAttachment:(const Attachment*) attachment whenReady:(AttachmentCompletionBlock)completion;

- (void) deliveryConfirm: (NSString*) messageId withDelivery: (Delivery*) delivery;
//- (void) generateToken: (NSString*) purpose validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler;
- (void) generatePairingTokenWithHandler: (InviteTokenHanlder) handler;

- (void) pairByToken: (NSString*) token;
- (void) acceptInvitation: (NSString*) token;

- (void) createGroupWithHandler:(CreateGroupHandler)handler;
- (void) inviteGroupMember:(Contact *)contact toGroup:(Group*)group onDone:(GenericResultHandler)doneHandler;
- (void) removeGroupMember:(GroupMembership *) member onDeletion:(GroupMemberDeleted)deletionHandler;
- (void) updateGroup:(Group *) group;

- (void) deleteGroup:(Group *) group onDeletion:(GroupHandler)handler;
- (void) joinGroup:(Group *) group onJoined:(GroupHandler)handler;
- (void) leaveGroup:(Group *) group onGroupLeft:(GroupHandler)handler;

- (void) hintApnsUnreadMessage: (NSUInteger) count handler: (GenericResultHandler) handler;

- (void) blockClient: (NSString*) clientId handler: (GenericResultHandler) handler;
- (void) unblockClient: (NSString*) clientId handler: (GenericResultHandler) handler;

- (void) depairClient: (NSString*) clientId handler: (GenericResultHandler) handler;

- (void) gotAPNSDeviceToken: (NSString*) deviceToken;
- (void) unregisterApns;

- (void) start: (BOOL) performRegistration;
- (void) stop;

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;

- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

- (void) downloadFinished:(Attachment *)theAttachment;
- (void) uploadFinished:(Attachment *)theAttachment;
- (void) downloadFailed:(Attachment *)theAttachment;
- (void) uploadFailed:(Attachment *)theAttachment;

- (void) updateRelationships;
- (void) updatePresence;
- (void) updateKey;

- (void)deleteInDatabaseAllMembersAndContactsofGroup:(Group*) group;

- (void) enqueueDownloadOfAttachment:(Attachment*) theAttachment;
- (void) enqueueUploadOfAttachment:(Attachment*) theAttachment;
- (void) dequeueDownloadOfAttachment:(Attachment*) theAttachment;
- (void) dequeueUploadOfAttachment:(Attachment*) theAttachment;

+ (NSString *) ownPublicKeyIdString;
+ (NSData *) ownPublicKeyId;
+ (NSData *) ownPublicKey;
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

+ (void) downloadDataFromURL:(NSString*)fromURL inQueue:(GCNetworkQueue*)queue withCompletion:(DataLoadedBlock)handler;
+ (HXOBackend*)instance;
+ (BOOL) use_elliptic_curves;

@end
