//
//  JsonRpcWebSocket.h
//  HoccerTalk
//
//  Created by David Siegel on 10.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// TODO: Document typical usage and write up constraints

@class SRWebSocket;

typedef void (^ResponseBlock)(id responseOrError, BOOL success);

@protocol JsonRpcWebSocketDelegate <NSObject>

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;
- (void) incomingMethodCallDidFail: (NSError*) error;
- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

@end

@interface JsonRpcError : NSObject

@property (nonatomic,strong) NSString * message;
@property (nonatomic,assign) NSInteger  code;
@property (nonatomic,strong) NSDictionary * data;

+ (JsonRpcError*) errorWithMessage: (NSString*) messgae code: (NSInteger) code data: (NSDictionary*) data;

@end

@interface JsonRpcWebSocket : NSObject

@property (nonatomic,strong) id<JsonRpcWebSocketDelegate> delegate;

- (id) initWithURLRequest: (NSURLRequest*) request;
- (void) open;
- (void) close;
- (void) reopenWithURLRequest: (NSURLRequest*) request;
- (void) notify: (NSString*) method withParams: (id) params;
- (void) invoke: (NSString*) method withParams: (id) params onResponse: (ResponseBlock) handler;
- (void) registerIncomingCall: (NSString*) methodName withSelector: (SEL) selector isNotification: (BOOL) notificationFlag;

@end