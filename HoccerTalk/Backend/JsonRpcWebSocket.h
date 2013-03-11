//
//  JsonRpcWebSocket.h
//  HoccerTalk
//
//  Created by David Siegel on 10.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol JsonRpcWebSocketDelegate <NSObject>

- (void) didFailWithError: (NSError*) error;

@end

@interface JsonRpcWebSocket : NSObject

@property (nonatomic,strong) id<JsonRpcWebSocketDelegate> delegate;

- (id) initWithURLRequest: (NSURLRequest*) request;

@end