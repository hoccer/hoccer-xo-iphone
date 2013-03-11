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

@interface JsonRpcWebSocket () <SRWebSocketDelegate>
{
    SRWebSocket * _websocket;
}

@end

@implementation JsonRpcWebSocket

- (id) initWithURLRequest: (NSURLRequest*) request {
    self = [super init];
    if (self != nil) {
        [self unmarshall: @"{blub"];
        [self unmarshall: @"{\"blub\": \"blah\"}"];

        return self;
        _websocket = [[SRWebSocket alloc] initWithURLRequest: request];
        _websocket.delegate = self;
        [_websocket open];
    }
    return self;
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

}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self.delegate didFailWithError: error];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    
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
/*
        if ([message objectForKey: @"method"] != nil) {
            if ([message objectForKey: @"result"] != nil || [message objectForKey: @"error"] != nil) {
                [self emitJsonRpcError: @"method message contains an 'error' or 'result' field" code: kJsonRpcInvalidRequest data: nil];
                return;
            }
        } else if ([message objectForKey: @"result"] != nil) {
            if ([message objectForKey: @"method"] != nil || [message objectForKey: @"error"] != nil) {
                [self emitJsonRpcError: @"result message contains an 'error' or 'method' field" code: kJsonRpcInvalidRequest data: nil];
                return;
            }
            if ([message objectForKey: @"id"] == nil) {
                [self emitJsonRpcError: @"result message does not contain an 'id' field" code: 0 data: nil];
                return;
            }
        } else if ([json objectForKey: @"error"] != nil) {
            if ([json objectForKey: @"method"] != nil || [json objectForKey: @"result"]) {
                [self emitJsonRpcError: @"error message contains a 'method' or 'result' field"];
                return NO;
            }
            if ([json objectForKey: @"id"] == nil) {
                [self emitJsonRpcError: @"error message does not contain an 'id' field"];
                return NO;
            }
        } else {
            [self emitJsonRpcError: @"message does not contain the 'method', 'result' or 'error' field"];
            return NO;
        }
 */

    } else {
        // error
    }
}

- (void) emitJsonRpcError: (NSString*) message code: (NSInteger) code data: (NSDictionary*) data {
    NSDictionary * errorDict;
    if (data != nil) {
        errorDict = @{ @"code": [NSNumber numberWithInteger: code], @"message": message, @"data": data};
    } else {
        errorDict = @{ @"code": [NSNumber numberWithInteger: code], @"message": message};
    }

    NSLog(@"%@", [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject: errorDict options: NSJSONWritingPrettyPrinted error: nil]  encoding:NSUTF8StringEncoding]);
    
    // TODO: write to web socket
    
    NSError * error = [NSError errorWithDomain: @"JSON RPC Error"
                                          code: code
                                      userInfo: data != nil ? @{@"NSDebugDescription": message, @"data": data} : @{@"NSDebugDescription": message}];
    [self.delegate didFailWithError: error];
}
@end
