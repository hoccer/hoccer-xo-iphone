//
//  JsonRpcWebSocket.h
//  HoccerXO
//
//  Created by David Siegel on 10.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// TODO: Document typical usage and write up constraints

@class SRWebSocket;

typedef void (^ResponseBlock)(id responseOrError, BOOL success);
typedef void (^ResultBlock)(id responseOrError);

@protocol JsonRpcWebSocketDelegate <NSObject>

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;
- (void) incomingMethodCallDidFail: (NSError*) error;
- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void) webSocket:(SRWebSocket *)webSocket didStartRequest:(unsigned long)requestId withOpenRequests:(unsigned long)openRequests;
- (void) webSocket:(SRWebSocket *)webSocket didFinishRequest:(unsigned long)requestId withOpenRequests:(unsigned long)openRequests;
- (void) webSocket:(SRWebSocket *)webSocket didSendWithOpenRequests:(unsigned long)openRequests;
- (void) webSocket:(SRWebSocket *)webSocket didReceiveWithOpenRequests:(unsigned long)openRequests;

@end

@interface JsonRpcError : NSObject

@property (nonatomic,strong) NSString * message;
@property (nonatomic,assign) NSInteger  code;
@property (nonatomic,strong) NSDictionary * data;

+ (JsonRpcError*) errorWithMessage: (NSString*) messgae code: (NSInteger) code data: (NSDictionary*) data;

@end

@interface JsonRpcWebSocket : NSObject

@property (nonatomic,strong) id<JsonRpcWebSocketDelegate> delegate;

- (id) init;
- (void) close;
- (void) openWithURLRequest: (NSURLRequest*) request protocols: (NSArray*) protocols allowUntrustedConnections:(BOOL)allowUntrustedConnections;
- (void) notify: (NSString*) method withParams: (id) params;
- (void) invoke: (NSString*) method withParams: (id) params onResponse: (ResponseBlock) handler;
- (void) registerIncomingCall: (NSString*) methodName withSelector: (SEL) selector isNotification: (BOOL) notificationFlag;
- (void) registerIncomingCall:(NSString*) methodName withSelector:(SEL)selector asyncResult:(BOOL) asyncResultFlag;
- (int) numberOfOpenRequests;
- (int) numberOfFlushedRequests;

@end