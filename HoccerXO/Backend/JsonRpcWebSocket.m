//
//  JsonRpcWebSocket.m
//  HoccerXO
//
//  Created by David Siegel on 10.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "JsonRpcWebSocket.h"

#import "SocketRocket/SRWebSocket.h"

#import "HXOUserDefaults.h"

static const NSInteger kJsonRpcParseError     = -32700;
static const NSInteger kJsonRpcInvalidRequest = -32600;
static const NSInteger kJsonRpcMethodNotFound = -32601;
static const NSInteger kJsonRpcInvalidParams  = -32602;
static const NSInteger kJsonRpcInternal       = -32603;

//-32000 to -32099	Server error

// TODO: clean-up error handling

static const NSTimeInterval kResponseTimeout = 30;

@interface JsonRpcWebSocket () <SRWebSocketDelegate>
{
    SRWebSocket * _websocket;
    long long _id;
    NSMutableDictionary * _responseHandlers;
    NSMutableDictionary * _rpcMethods;
    NSString * _verbosityLevel;
}

- (void) serverDidNotRespond: (NSNumber*) jsonRpcId;

@end

@interface JsonRpcHandler : NSObject

@property (nonatomic, assign) SEL  selector;
@property (nonatomic, assign) BOOL isNotification;

+ (JsonRpcHandler*) jsonRpcHanlder: (SEL) selector isNotification: (BOOL) notificationFlag;

@end

@implementation JsonRpcWebSocket

- (NSString *) verbosityLevel {
    if (_verbosityLevel == nil) {
        _verbosityLevel = [[HXOUserDefaults standardUserDefaults] valueForKey: @"jsonrpcverbosity"];
    }
    return _verbosityLevel;
}

- (id) init {
    self = [super init];
    if (self != nil) {
        _id = 0;
        _responseHandlers = [[NSMutableDictionary alloc] init];
        _rpcMethods = [[NSMutableDictionary alloc] init];
    }
    return self;
}


- (void) close {
    [_websocket close];
}

- (void) openWithURLRequest:(NSURLRequest *)request protocols: (NSArray*) protocols {
    _websocket = [[SRWebSocket alloc] initWithURLRequest: request protocols: protocols];
    _websocket.delegate = self;
    [_websocket open];
}

#pragma mark - Web Socket Delegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if ([message isKindOfClass: [NSString class]]) {
        if ([[self verbosityLevel]isEqualToString:@"dump"]) {NSLog(@"JSON RECV<-: %@",message);}
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

- (void) registerIncomingCall:(NSString*) methodName withSelector:(SEL)selector isNotification:(BOOL)notificationFlag {
    _rpcMethods[methodName] = [JsonRpcHandler jsonRpcHanlder: selector isNotification: notificationFlag];
}

- (void) unmarshall: (NSString*) jsonString{
    NSError * error;
    id json = [NSJSONSerialization JSONObjectWithData: [jsonString dataUsingEncoding:NSUTF8StringEncoding] options: 0 error: &error];
    if (json == nil) {
        [self emitJsonRpcError: [NSString stringWithFormat: @"JSON parse error: %@", error.userInfo[@"NSDebugDescription"]]
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
        if ( ! [message[@"jsonrpc"] isEqual: @"2.0"]) {
            [self emitJsonRpcError: @"message does not have a 'jsonrpc' field with value '2.0'" code: kJsonRpcInvalidRequest data: nil];
            return;
        }
        if (message[@"method"] != nil) {
            [self processRequest: message];
        } else {
            [self processResponse: message];
        }
    } else {
        // kaputt
    }
}

- (void) processRequest: (NSDictionary*) request {
    JsonRpcHandler * handler = _rpcMethods[request[@"method"]];
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON request<-: %@ id:%@",request[@"method"], request[@"id"]);}
    if (handler != nil && [self.delegate respondsToSelector: handler.selector]) {
        if (handler.isNotification) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.delegate performSelector: handler.selector withObject: request[@"params"]];
        } else {
            id resultOrError = [self.delegate performSelector: handler.selector withObject: request[@"params"]];
#pragma clang diagnostic pop
            if ([resultOrError isKindOfClass: [JsonRpcError class]]) {
                [self respondWithError: resultOrError id: request[@"id"]];
            } else {
                [self respondWithResult: resultOrError id: request[@"id"]];
            }
        }
    } else {
        [self emitJsonRpcError: [NSString stringWithFormat: @"method '%@' not found", request[@"method"]] code: kJsonRpcMethodNotFound data: nil];
    }
}

- (void) processResponse: (NSDictionary*) responseOrError {
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {
        NSLog(@"JSON response<-: %@ %@ id:%@",
              responseOrError[@"result"]?@"<result>":@"<no-result>",
              responseOrError[@"error"]?responseOrError[@"error"]:@"<no-error>",
              responseOrError[@"id"]);
    }
    NSNumber * theId = responseOrError[@"id"];
    if (theId == nil) {
        [self emitJsonRpcError: @"Got response without id" code: 0 data: nil];
        return;
    }

    ResponseBlock handler = _responseHandlers[theId][@"handler"];
    NSTimer * timer = _responseHandlers[theId][@"timer"];
    [timer invalidate];
    [_responseHandlers removeObjectForKey: theId];

    if (responseOrError[@"result"] != nil) {
        handler(responseOrError[@"result"], YES);
    } else if (responseOrError[@"error"] != nil) {
        handler(responseOrError[@"error"], NO);
    } else {
        // kaputt
    }
}

- (void) notify: (NSString*) method withParams: (id) params {
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON notify->: %@",method);}
    NSDictionary * notification = @{ @"jsonrpc": @"2.0", @"method": method, @"params": params};
    [self sendJson: notification];
}

- (void) invoke: (NSString*) method withParams: (id) params onResponse: (ResponseBlock) handler {
    NSNumber * theId = [self nextId];
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON invoke->: %@ id:%@",method, theId);}
    NSDictionary * methodCall = @{ @"jsonrpc": @"2.0", @"method": method, @"params": params, @"id": theId};
    // NSLog(@"jsonrpc method: %@", methodCall);
    _responseHandlers[theId] = @{ @"handler": [handler copy],
                                  @"timer": 
                                      [NSTimer scheduledTimerWithTimeInterval: kResponseTimeout target: self selector: @selector(serverDidNotRespond:) userInfo: theId repeats: NO]
                                  };

    if (![self sendJson: methodCall]) {
        [self droppedRequest:theId];
    };
}

- (BOOL) sendJson: (NSDictionary*) jsonObject {
    NSData * myPayloaddata = [NSJSONSerialization dataWithJSONObject: jsonObject options: 0 error: nil];
    NSString * myPayloadString = [[NSString alloc] initWithData:myPayloaddata encoding:NSUTF8StringEncoding];
    if ([[self verbosityLevel]isEqualToString:@"dump"]) {NSLog(@"JSON SEND->: %@",myPayloadString);}
    if (_websocket.readyState == SR_OPEN) {
        [_websocket send: myPayloadString];
        return YES;
    } else {
        NSLog(@"sendJson: sending failed, connection not open");
    }
    return NO;
}

- (NSNumber*) nextId {
    return @(_id++);
}

- (void) droppedRequest: (NSNumber*) jsonRpcId {
    NSLog(@"JsonRpc: request %@ was dropped (no connection)", jsonRpcId);
    [_responseHandlers removeObjectForKey: jsonRpcId];
}

- (void) serverDidNotRespond: (NSNumber*) jsonRpcId {
    NSLog(@"Server did not respond within %f seconds.", kResponseTimeout);
    [_responseHandlers removeObjectForKey: jsonRpcId];
}

- (void) respondWithResult: (id) result id: (NSNumber*) theId {
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON response->: <result> id:%@", theId);}
    NSDictionary * response = @{@"jsonrpc": @"2.0", @"result": result, @"id": theId};
    [self sendJson: response];
}

- (void) respondWithError: (JsonRpcError*) error id: (NSNumber*) theId {
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON response->: <error> id:%@", theId);}
    NSDictionary * response =@{ @"jsonrpc": @"2.0",
                                @"id": theId,
                                @"error": @{ @"message": error.message,
                                             @"code": @(error.code),
                                             @"data": error.data
                                           }
                                };
    [self sendJson: response];

}

- (void) emitJsonRpcError: (NSString*) message code: (NSInteger) code data: (NSDictionary*) data {
    NSDictionary * errorDict;
    if (data != nil) {
        errorDict = @{ @"code": @(code), @"message": message, @"data": data};
    } else {
        errorDict = @{ @"code": @(code), @"message": message};
    }

    [self sendJson: errorDict];

    NSError * error = [NSError errorWithDomain: @"JSON RPC Error"
                                          code: code
                                      userInfo: data != nil ? @{@"NSDebugDescription": message, @"data": data} : @{@"NSDebugDescription": message}];
    [self.delegate didReceiveInvalidJsonRpcMessage: error];
}

@end


@implementation JsonRpcError

+ (JsonRpcError*) errorWithMessage: (NSString*) messgae code: (NSInteger) code data: (NSDictionary*) data {
    JsonRpcError * error = [[JsonRpcError alloc] init];
    error.message = messgae;
    error.code = code;
    error.data = data;
    return error;
}

@end

@implementation JsonRpcHandler

+ (JsonRpcHandler*) jsonRpcHanlder: (SEL) selector isNotification: (BOOL) notificationFlag {
    JsonRpcHandler * handler = [[JsonRpcHandler alloc] init];
    handler.selector = selector;
    handler.isNotification = notificationFlag;
    return handler;
}

@end

