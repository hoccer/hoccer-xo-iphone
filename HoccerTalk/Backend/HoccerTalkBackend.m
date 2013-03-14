//
//  HoccerTalkBackend.m
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HoccerTalkBackend.h"

#import "JsonRpcWebSocket.h"

@interface HoccerTalkBackend ()
{
    JsonRpcWebSocket * _serverConnection;
}

- (void) identify;

@end

@implementation HoccerTalkBackend

- (id) init {
    self = [super init];
    if (self != nil) {
        NSURL * url = [NSURL URLWithString: @"ws://development.hoccer.com:7000/"];
        _serverConnection = [[JsonRpcWebSocket alloc] initWithURLRequest: [[NSURLRequest alloc] initWithURL: url]];
        _serverConnection.delegate = self;
        [_serverConnection registerIncomingCall: @"pipapo" withSelector:@selector(piPaPo:) isNotification: NO];
        [_serverConnection open];
    }
    return self;
}

#pragma mark - Outgoing RPC Calls

- (void) identify {
    [_serverConnection invoke: @"identify" withParams: @[@"david - who else?"] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"got result: %@", responseOrError);
        } else {
            NSLog(@"got error: %@", responseOrError);
        }
    }];
}

#pragma mark - Incoming RPC Calls

- (id) piPaPo: (NSArray*) params {
    if ([params count] == 0) {
        return [JsonRpcError errorWithMessage:@"Got no params - that's not good." code: 23 data: nil];
    }
    return @[@"pi", @"pa", @"po"];
}

#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@", error);
}

- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error {
    NSLog(@"didReceiveInvalidJsonRpcMessage: %@", error);
}

- (void) webSocketDidOpen: (SRWebSocket*) webSocket {
    NSLog(@"webSocketDidOpen");
    [self identify];
}

- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket didCloseWithCode %d reason: %@ clean: %d", code, reason, wasClean);
}

- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

@end
