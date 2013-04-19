//
//  HoccerTalkBackend.h
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Config.h"

#import "JsonRpcWebSocket.h"

@class Contact;
@class Delivery;
@class TalkMessage;
@class Attachment;
@class AppDelegate;

typedef void (^InviteTokenHanlder)(NSString*);
typedef void (^GenerateIdHandler)(NSString*);
typedef void (^SrpHanlder)(NSString*);
typedef void (^RelationshipHandler)(NSArray*);
typedef void (^PresenceHandler)(NSArray*);
typedef void (^PublicKeyHandler)(NSDictionary*);
typedef void (^GenericResultHandler)(BOOL);

@protocol HoccerTalkDelegate <NSObject>

- (NSString*) clientId;
- (NSString*) apnDeviceToken;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, nonatomic) NSManagedObjectModel *managedObjectModel;

- (void) didPairWithStatus: (BOOL) status; // pregnant...

@optional

-(void) backendDidStop;

@end

@interface HoccerTalkBackend : NSObject <JsonRpcWebSocketDelegate>

@property (nonatomic, weak) AppDelegate * delegate;
@property (nonatomic, strong) NSURLConnection *avatarUploadConnection;

- (id) initWithDelegate: (AppDelegate *) theAppDelegate;

- (TalkMessage*) sendMessage: (NSString*) text toContact: (Contact*) contact withAttachment: (Attachment*) attachment;
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

- (void) updateRelationships;
- (void) updatePresence;



- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                         payloadData:(NSData *)payload
                       payloadStream:(NSInputStream*)stream
                             headers:(NSDictionary *)headers;

@end
