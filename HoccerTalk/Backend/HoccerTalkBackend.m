//
//  HoccerTalkBackend.m
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HoccerTalkBackend.h"

#import "JsonRpcWebSocket.h"
#import "NSManagedObject+RPCDictionary.h"
#import "Message.h"
#import "Delivery.h"

@interface HoccerTalkBackend ()
{
    JsonRpcWebSocket * _serverConnection;
    BOOL _isConnected;
}

- (void) identify;

@end

@implementation HoccerTalkBackend

- (id) init {
    self = [super init];
    if (self != nil) {
        _isConnected = NO;
        _serverConnection = [[JsonRpcWebSocket alloc] initWithURLRequest: [self urlRequest]];
        _serverConnection.delegate = self;
        [_serverConnection registerIncomingCall: @"incomingDelivery" withSelector:@selector(incomingDelivery:) isNotification: YES];
        [_serverConnection open];
    }
    return self;
}

- (NSURLRequest*) urlRequest {
    NSURL * url = [NSURL URLWithString: @"ws://development.hoccer.com:7000/"];
    return [[NSURLRequest alloc] initWithURL: url];
}

- (Message*) sendMessage:(NSString *)text toContact:(Contact *)contact {
    Message * message = [super sendMessage: text toContact: contact];
    if (_isConnected) {
        [self deliveryRequest: message];
    }
    return message;
}

#pragma mark - Outgoing RPC Calls

- (void) identify {
    [_serverConnection invoke: @"identify" withParams: @[@"david - who else?"] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            _isConnected = YES;
            // TODO: flush queue by sending all deliveries with state 'new'
            NSLog(@"identify(): got result: %@", responseOrError);
        } else {
            NSLog(@"identify(): got error: %@", responseOrError);
        }
    }];
}

- (void) deliveryRequest: (Message*) message {
    NSDictionary * messageDict = [message rpcDictionary];
    NSArray * orderedDeliveries = [message.deliveries allObjects];
    NSMutableArray * deliveryDicts = [[NSMutableArray alloc] init];
    for (Delivery * delivery in orderedDeliveries) {
        [deliveryDicts addObject: [delivery rpcDictionary]];
    }
    [_serverConnection invoke: @"deliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"returned deliveries: %@", responseOrError);
            NSArray * updatedDeliveryDicts = (NSArray*)responseOrError;
            int i = 0;
            for (Delivery * delivery in orderedDeliveries) {
                [delivery updateWithDictionary: updatedDeliveryDicts[i++]];
            }
        } else {
            NSLog(@"deliveryRequest failed: %@", responseOrError);
        }
    }];
}

#pragma mark - Incoming RPC Calls

- (void) incomingDelivery: (NSArray*) params {
    if (params.count != 2) {
        NSLog(@"incomingDelivery requires an array of two parameters (delivery, message), but got %d parameters.", params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"incomingDelivery: parameter 0 must be an object");
        return;
    }
    NSDictionary * deliveryDict = params[0];
    if ( ! [params[1] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"incomingDelivery: parameter 1 must be an object");
        return;
    }
    NSDictionary * messageDict = params[1];
    NSLog(@"==== incomingDelivery() called... tada!");
    [self receiveMessage: messageDict withDelivery: deliveryDict];
}

- (void) outgoingDelivery: (NSArray*) params {
    if (params.count != 1) {
        NSLog(@"incomingDelivery requires an array of two parameters (delivery, message), but got %d parameters.", params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        return;
    }
    NSDictionary * deliveryDict = params[0];
}

#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@", error);
    _isConnected = NO;
    [_serverConnection reopenWithURLRequest: [self urlRequest]];
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
    _isConnected = NO;
    [_serverConnection reopenWithURLRequest: [self urlRequest]];
}

- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

@end
