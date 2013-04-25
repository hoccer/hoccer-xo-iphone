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

typedef void (^InviteTokenHanlder)(NSString*);
typedef void (^GenerateIdHandler)(NSString*);
typedef void (^SrpHanlder)(NSString*);
typedef void (^RelationshipHandler)(NSArray*);
typedef void (^PresenceHandler)(NSArray*);
typedef void (^PublicKeyHandler)(NSDictionary*);
typedef void (^GenericResultHandler)(BOOL);

@protocol HXODelegate <NSObject>

- (NSString*) apnDeviceToken;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, nonatomic) NSManagedObjectModel *managedObjectModel;

- (void) didPairWithStatus: (BOOL) status; // pregnant...

@optional

-(void) backendDidStop;

@end

@interface HXOBackend : NSObject <JsonRpcWebSocketDelegate>

@property (nonatomic, weak) AppDelegate * delegate;
@property (nonatomic, strong) NSURLConnection *avatarUploadConnection;

@property (nonatomic, strong) NSDate *latestKnownServerTime;
@property (nonatomic, strong) NSDate *latestKnownServerTimeAtClientTime;
@property (nonatomic) NSTimeInterval latestKnownServerTimeOffset;

- (id) initWithDelegate: (AppDelegate *) theAppDelegate;

- (HXOMessage*) sendMessage: (NSString*) text toContact: (Contact*) contact withAttachment: (Attachment*) attachment;
- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary;

- (void) deliveryConfirm: (NSString*) messageId withDelivery: (Delivery*) delivery;
- (void) generateToken: (NSString*) purpose validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler;
- (void) pairByToken: (NSString*) token;
- (void) acceptInvitation: (NSString*) token;

- (void) hintApnsUnreadMessage: (NSUInteger) count handler: (GenericResultHandler) handler;

- (void) blockClient: (NSString*) clientId handler: (GenericResultHandler) handler;
- (void) unblockClient: (NSString*) clientId handler: (GenericResultHandler) handler;

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

- (void) updateRelationships;
- (void) updatePresence;
- (void) updateKey;

+ (NSString *) ownPublicKeyIdString;
+ (NSData *) ownPublicKeyId;
+ (NSData *) ownPublicKey;
+ (NSData *) calcKeyId:(NSData *) myKeyBits;
+ (NSString *) keyIdString:(NSData *) myKeyId;


- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                         payloadData:(NSData *)payload
                       payloadStream:(NSInputStream*)stream
                             headers:(NSDictionary *)headers;

@end
