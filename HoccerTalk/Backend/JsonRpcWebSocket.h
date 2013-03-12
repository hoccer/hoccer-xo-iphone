//
//  JsonRpcWebSocket.h
//  HoccerTalk
//
//  Created by David Siegel on 10.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SRWebSocket;

@protocol JsonRpcWebSocketDelegate <NSObject>

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;

@optional

- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

@end

@interface JsonRpcWebSocket : NSObject

@property (nonatomic,strong) id<JsonRpcWebSocketDelegate> delegate;

- (id) initWithURLRequest: (NSURLRequest*) request;
- (void) notify: (NSString*) method withParams: (NSDictionary*) params;
- (void) invoke: (NSString*) method withParams: (NSDictionary*) params onResponse: (SEL) handler;
@end