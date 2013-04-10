//
//  HoccerTalkBackend.h
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JsonRpcWebSocket.h"

@class Contact;
@class Delivery;
@class TalkMessage;
@class Attachment;
@class AppDelegate;

typedef void (^InviteTokenHanlder)(NSString*);
typedef void (^PairingHandler)(BOOL);
typedef void (^RelationshipHandler)(NSArray*);
typedef void (^PresenceHandler)(NSArray*);

@protocol HoccerTalkDelegate <NSObject>

- (NSString*) clientId;
- (NSString*) apnDeviceToken;
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, nonatomic) NSManagedObjectModel *managedObjectModel;

@end

@interface HoccerTalkBackend : NSObject <JsonRpcWebSocketDelegate>

{
    NSString *userAgent;
}

@property (nonatomic, weak) AppDelegate * delegate;
@property (nonatomic, strong) NSURLConnection *avatarUploadConnection;

- (id) initWithDelegate: (AppDelegate *) theAppDelegate;

- (TalkMessage*) sendMessage: (NSString*) text toContact: (Contact*) contact withAttachment: (Attachment*) attachment;
- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary;

- (void) deliveryConfirm: (NSString*) messageId withDelivery: (Delivery*) delivery;
- (void) generateToken: (NSString*) purpose validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler;
- (void) pairByToken: (NSString*) token pairingHandler: (PairingHandler) handler;

- (void) gotAPNSDeviceToken: (NSString*) deviceToken;
- (void) unregisterApns;

- (void) start;

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;

- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

- (void) downloadFinished:(Attachment *)theAttachment;

- (void) updateRelationships;


- (NSMutableURLRequest *)httpRequest:(NSString *)method
                         absoluteURI:(NSString *)URLString
                             payload:(NSData *)payload
                             headers:(NSDictionary *)headers;

@end
