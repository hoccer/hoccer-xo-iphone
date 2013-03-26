//
//  HoccerTalkBackend.h
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JsonRpcWebSocket.h"
#import "ChatBackend.h"

@protocol HoccerTalkDelegate <NSObject>

- (NSString*) clientId;

@end

@interface HoccerTalkBackend : ChatBackend <JsonRpcWebSocketDelegate>

@property (nonatomic, weak) id<HoccerTalkDelegate> delegate;

- (id) init;

- (void) webSocketDidFailWithError: (NSError*) error;
- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error;

- (void) webSocketDidOpen: (SRWebSocket*) webSocket;
- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;


@end
