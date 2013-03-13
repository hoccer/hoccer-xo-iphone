//
//  JsonRpcWebSocket.m
//  HoccerTalk
//
//  Created by David Siegel on 10.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "JsonRpcWebSocket.h"

#import "SocketRocket/SRWebSocket.h"

static const NSInteger kJsonRpcParseError     = -32700;
static const NSInteger kJsonRpcInvalidRequest = -32600;
static const NSInteger kJsonRpcMethodNotFound = -32601;
static const NSInteger kJsonRpcInvalidParams  = -32602;
static const NSInteger kJsonRpcInternal       = -32603;

//-32000 to -32099	Server error

static const NSTimeInterval kResponseTimeout = 10;

@interface JsonRpcWebSocket () <SRWebSocketDelegate>
{
    SRWebSocket * _websocket;
    long long _id;
    NSMutableDictionary * _responseHandlers;
}

- (void) serverDidNotRespond: (NSNumber*) jsonRpcId;

@end

@implementation JsonRpcWebSocket

- (id) initWithURLRequest: (NSURLRequest*) request {
    self = [super init];
    if (self != nil) {
        _id = 0;
        _responseHandlers = [[NSMutableDictionary alloc] init];
        _websocket = [[SRWebSocket alloc] initWithURLRequest: request];
        _websocket.delegate = self;
    }
    return self;
}

- (void) open {
    [_websocket open];
}

#pragma mark - Web Socket Delegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if ([message isKindOfClass: [NSString class]]) {
        [self unmarshall: message];
    } else if ([message isKindOfClass: [NSData class]]) {
        NSLog(@"ERROR: got binary message, but binary messages are not implemented");
    } else {
        NSLog(@"ERROR: expected NSString (or NSData)");
    }
    
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    if ([self.delegate respondsToSelector:@selector(webSocketDidOpen:)]) {
        [self.delegate webSocketDidOpen: webSocket];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self.delegate webSocketDidFailWithError: error];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    if ([self.delegate respondsToSelector:@selector(webSocket:didCloseWithCode:reason:wasClean:)]) {
        [self.delegate webSocket: webSocket didCloseWithCode: code reason: reason wasClean: wasClean];
    }
}

#pragma mark - JSON RPC

- (void) unmarshall: (NSString*) jsonString{
    NSError * error;
    id json = [NSJSONSerialization JSONObjectWithData: [jsonString dataUsingEncoding:NSUTF8StringEncoding] options: 0 error: &error];
    if (json == nil) {
        [self emitJsonRpcError: [NSString stringWithFormat: @"JSON parse error: %@", [error.userInfo objectForKey: @"NSDebugDescription"]]
                          code: kJsonRpcParseError data: nil];
        return;
    }

    if ([json isKindOfClass: [NSArray class]]) {
        [self processBatch: json];
    } else if ([json isKindOfClass: [NSDictionary class]]) {
        [self processMessage: json];
    } else {
        [self emitJsonRpcError: @"message is not an array (aka batch) or object (aka dictionary)" code: kJsonRpcInvalidRequest data: nil];
    }
}

- (void) processBatch: (NSArray*) batch {
    for (id object in batch) {
        [self processMessage: object];
    }
}

- (void) processMessage: (id) message {
    if ([message isKindOfClass: [NSDictionary class]]) {
        if ( ! [[message objectForKey: @"jsonrpc"] isEqual: @"2.0"]) {
            [self emitJsonRpcError: @"message does not have a 'jsonrpc' field with value '2.0'" code: kJsonRpcInvalidRequest data: nil];
            return;
        }
        if ([message objectForKey: @"method"] != nil) {
            [self processRequest: message];
        } else {
            [self processResponse: message];
        }
    } else {
        // kaputt
    }
}

- (void) processRequest: (NSDictionary*) request {
}

- (void) processResponse: (NSDictionary*) responseOrError {
    NSNumber * theId = [responseOrError objectForKey: @"id"];
    if (theId == nil) {
        [self emitJsonRpcError: @"Got response without id" code: 0 data: nil];
        return;
    }

    ResponseBlock handler = [_responseHandlers objectForKey: theId];
    [_responseHandlers removeObjectForKey: theId];

    if ([responseOrError objectForKey: @"result"] != nil) {
        handler([responseOrError objectForKey: @"result"], YES);
    } else if ([responseOrError objectForKey: @"error"] != nil) {
        handler([responseOrError objectForKey: @"error"], NO);
    } else {
        // kaputt
    }
}

- (void) notify: (NSString*) method withParams: (id) params {
    NSDictionary * notification = @{ @"jsonrpc": @"2.0", @"method": method, @"params": params};
    [self sendJson: notification];
}

- (void) invoke: (NSString*) method withParams: (id) params onResponse: (ResponseBlock) handler {
    NSNumber * theId = [self nextId];
    NSDictionary * methodCall = @{ @"jsonrpc": @"2.0", @"method": method, @"params": params, @"id": theId};
    [_responseHandlers setObject:  [handler copy] forKey: theId];
    [NSTimer timerWithTimeInterval: kResponseTimeout target: self selector: @selector(serverDidNotRespond) userInfo: theId repeats: NO];

    [self sendJson: methodCall];
}

- (void) sendJson: (NSDictionary*) jsonObject {
    [_websocket send: [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject: jsonObject options: 0 error: nil]  encoding:NSUTF8StringEncoding]];
}

- (NSNumber*) nextId {
    return [NSNumber numberWithLongLong: _id++];
}

- (void) serverDidNotRespond: (NSNumber*) jsonRpcId {
    NSLog(@"Server did not respond withing %f seconds.", kResponseTimeout);
    [_responseHandlers removeObjectForKey: jsonRpcId];
}

- (void) emitJsonRpcError: (NSString*) message code: (NSInteger) code data: (NSDictionary*) data {
    NSDictionary * errorDict;
    if (data != nil) {
        errorDict = @{ @"code": [NSNumber numberWithInteger: code], @"message": message, @"data": data};
    } else {
        errorDict = @{ @"code": [NSNumber numberWithInteger: code], @"message": message};
    }

    [self sendJson: errorDict];

    NSError * error = [NSError errorWithDomain: @"JSON RPC Error"
                                          code: code
                                      userInfo: data != nil ? @{@"NSDebugDescription": message, @"data": data} : @{@"NSDebugDescription": message}];
    [self.delegate didReceiveInvalidJsonRpcMessage: error];
}

@end
