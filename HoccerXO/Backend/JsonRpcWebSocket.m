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

//#define TEST_COMPRESSION

#ifdef TEST_COMPRESSION
#import "NSData+Compression.h"
#import "NSData+GZIP.h"
#import "NSData+DictCompression.h"
#endif

static const NSInteger kJsonRpcParseError     = -32700;
static const NSInteger kJsonRpcInvalidRequest = -32600;
static const NSInteger kJsonRpcMethodNotFound = -32601;
//static const NSInteger kJsonRpcInvalidParams  = -32602;
//static const NSInteger kJsonRpcInternal       = -32603;

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
    NSUInteger _flushedRequests;
}

- (void) serverDidNotRespond: (NSNumber*) jsonRpcId;

@end

@interface JsonRpcHandler : NSObject

@property (nonatomic, assign) SEL  selector;
@property (nonatomic, assign) BOOL isNotification;
@property (nonatomic, assign) BOOL asyncResult;

+ (JsonRpcHandler*) jsonRpcHanlder: (SEL) selector isNotification: (BOOL) notificationFlag asyncResult:(BOOL)asyncResultFlag;

@end

@implementation JsonRpcWebSocket

- (NSString *) verbosityLevel {
    if (_verbosityLevel == nil) {
        _verbosityLevel = [[HXOUserDefaults standardUserDefaults] valueForKey: @"jsonrpcverbosity"];
    }
    // return @"dump";
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

- (void) openWithURLRequest:(NSURLRequest *)request protocols: (NSArray*) protocols allowUntrustedConnections:(BOOL)allowUntrustedConnections {
    // NSLog(@"Backend: websocket openWithURLRequest: %@", request.URL);
    _websocket = [[SRWebSocket alloc] initWithURLRequest: request protocols: protocols];
    _websocket.delegate = self;
    _websocket.allowUntrustedConnections = allowUntrustedConnections;
    [_websocket open];
}

#pragma mark - Web Socket Delegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if ([self.delegate respondsToSelector:@selector(webSocket:didReceiveWithOpenRequests:)]) {
        [self.delegate webSocket:webSocket didReceiveWithOpenRequests:_responseHandlers.count];
    }
    if ([message isKindOfClass: [NSString class]]) {
        if ([[self verbosityLevel]isEqualToString:@"dump"]) {
            NSLog(@"JSON RECV<-: %@",message);
#ifdef TEST_COMPRESSION
            NSData * myPayloaddata = [message dataUsingEncoding:NSUTF8StringEncoding];
            [self testCompression:myPayloaddata];
#endif
        }
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
    [self flushOpenRequests];
    if ([self.delegate respondsToSelector:@selector(webSocket:didCloseWithCode:reason:wasClean:)]) {
        [self.delegate webSocket: webSocket didCloseWithCode: code reason: reason wasClean: wasClean];
    }
}

- (int) numberOfOpenRequests {
    return (int)_responseHandlers.count;
}

- (int) numberOfFlushedRequests {
    return (int)_flushedRequests;
}

#pragma mark - JSON RPC

- (void) registerIncomingCall:(NSString*) methodName withSelector:(SEL)selector isNotification:(BOOL)notificationFlag {
    _rpcMethods[methodName] = [JsonRpcHandler jsonRpcHanlder: selector isNotification: notificationFlag asyncResult:NO];
}

- (void) registerIncomingCall:(NSString*) methodName withSelector:(SEL)selector asyncResult:(BOOL)asyncResultFlag {
    _rpcMethods[methodName] = [JsonRpcHandler jsonRpcHanlder: selector isNotification: NO asyncResult:asyncResultFlag];
}

- (void) unmarshall: (NSString*) jsonString{
    NSError * error;
    @try {
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
    } @catch (NSException * ex) {
        NSLog(@"ERROR: unmarshall: parsing json, jsonData = %@, ex=%@", jsonString, ex);
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
            if (!handler.asyncResult) {
                id resultOrError = [self.delegate performSelector: handler.selector withObject: request[@"params"]];
                if ([resultOrError isKindOfClass: [JsonRpcError class]]) {
                    [self respondWithError: resultOrError id: request[@"id"]];
                } else {
                    [self respondWithResult: resultOrError id: request[@"id"]];
                }
            } else {
                [self.delegate performSelector: handler.selector withObject: request[@"params"] withObject:^(id resultOrError){
                    if ([resultOrError isKindOfClass: [JsonRpcError class]]) {
                        [self respondWithError: resultOrError id: request[@"id"]];
                    } else {
                        [self respondWithResult: resultOrError id: request[@"id"]];
                    }
                }];
            }
        }
#pragma clang diagnostic pop
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
    NSDictionary  * responseHandler = _responseHandlers[theId];
    if (responseHandler == nil) {
        NSLog(@"Late response for request id %@, response dropped", theId);
        return;
    }

    ResponseBlock handler = responseHandler[@"handler"];
    NSTimer * timer = responseHandler[@"timer"];
    [timer invalidate];
    [_responseHandlers removeObjectForKey: theId];

    if (responseOrError[@"result"] != nil) {
        handler(responseOrError[@"result"], YES);
    } else if (responseOrError[@"error"] != nil) {
        handler(responseOrError[@"error"], NO);
    } else {
        // kaputt
    }
    [self increaseTimeoutForRequestsAfterId:theId];

    if ([self.delegate respondsToSelector:@selector(webSocket:didFinishRequest:withOpenRequests:)]) {
        [self.delegate webSocket: _websocket didFinishRequest:[theId unsignedLongValue] withOpenRequests:_responseHandlers.count];
    }
}

- (void) increaseTimeoutForRequestsAfterId:(NSNumber*)requestId {
    NSDate * newFireDate = [NSDate dateWithTimeIntervalSinceNow: kResponseTimeout];
    // NSLog(@"increaseTimeoutForRequestsAfterId %@ to firedate %@", requestId, newFireDate);
    int numIncreased = 0;
    NSArray * allResponses = [_responseHandlers allKeys];
    for (id key in allResponses) {
        if ([key longLongValue] > [requestId longLongValue]) {
            NSTimer * timer = _responseHandlers[key][@"timer"];
            [timer setFireDate:newFireDate];
            ++numIncreased;
        }
    }
    // NSLog(@"increaseTimeoutForRequestsAfterId %@ - increased %d timeouts to firedate %@", requestId, numIncreased, newFireDate);
}

- (void) notify: (NSString*) method withParams: (id) params {
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON notify->: %@",method);}
    NSDictionary * notification;
    if (params != nil) {
        notification = @{ @"jsonrpc": @"2.0", @"method": method, @"params": params};
    } else {
        notification = @{ @"jsonrpc": @"2.0", @"method": method};
    }
    [self sendJson: notification];
}

- (void) invoke: (NSString*) method withParams: (id) params onResponse: (ResponseBlock) handler {
    NSNumber * theId = [self nextId];
    if ([[self verbosityLevel]isEqualToString:@"trace"]) {NSLog(@"JSON invoke->: %@ id:%@",method, theId);}
    NSDictionary * methodCall;
    if (params != nil) {
        methodCall = @{ @"jsonrpc": @"2.0", @"method": method, @"params": params, @"id": theId};
    } else {
        methodCall = @{ @"jsonrpc": @"2.0", @"method": method, @"id": theId};
    }
    // NSLog(@"jsonrpc method: %@", methodCall);
    _responseHandlers[theId] = @{ @"handler": [handler copy],
                                  @"timer": 
                                      [NSTimer scheduledTimerWithTimeInterval: kResponseTimeout target: self selector: @selector(serverDidNotRespond:) userInfo: theId repeats: NO]
                                  };

    if (![self sendJson: methodCall]) {
        [self droppedRequest:theId];
    } else {
        if ([self.delegate respondsToSelector:@selector(webSocket:didStartRequest:withOpenRequests:)]) {
            [self.delegate webSocket:_websocket didStartRequest: [theId unsignedLongValue] withOpenRequests:_responseHandlers.count];
        }
    }
}

#ifdef TEST_COMPRESSION

- (void)testCompression:(NSData*)myPayloaddata {
    NSArray * dict = @[
                       @"\"jsonrpc\":\"2.0\",\"method\":\"getTime\",\"id\":",
                       @"\"jsonrpc\":\"2.0\",\"params\":[" ,
                       @"\"jsonrpc\":\"2.0\",\"id\":" ,
                       @"\"method\":\"updatePresence\"" ,
                       @"\"method\":\"modifyPresence\"" ,
                       @"\"connectionStatus\":\"online\"",
                       @"\"connectionStatus\":\"offline\"",
                       @"\"method\":\"getEncryptedGroupKeys\"",
                       @"\"method\":\"groupMemberUpdated\"",
                       @"\"method\":\"presenceModified\"",
                       @"\"method\":\"destroyEnvironment\"",
                       @"\"method\":\"updateEnvironment\"",
                       @"\"groupType\":\"nearby\"",
                       @"\"connectionStatus\":\"",
                       @"\"keyCiphertext\":",
                       @"\"role\":\"member\"",
                       @"\"role\":\"admin\"",
                       @"\"state\":\"none\"",
                       @"\"state\":\"exists\"",
                       @"\"state\":\"delivered\"",
                       @"\"state\":\"joined\"",
                       @"\"state\":\"",
                       @"\"clientStatus\":\"",
                       @"\"result\":null",
                       @"\"jsonrpc\":\"2.0\"",
                       @"\"RENEW\",\"RENEW\"",
                       @"\"params\":[",
                       @"\"method\":",
                       @"\"result\":",
                       @"\"timeUpdated",
                       @"\"groupId\":",
                       @"\"clientId\":",
                       @"\"senderId\":",
                       @"\"receiverId\":",
                       @"\"messageTag\":",
                       @"\"messageId\":",
                       @"\"geoLocation\":",
                       @"group",
                       @"client",
                       @"system",
                       @"Version",
                       @"Name",
                       @"Time",
                       @",\"id\":",
                       ];
    
    NSString * dictString = [dict componentsJoinedByString:@""];
    
    ;
    //NSLog(@"Using dict:%@",dictString);
    NSDate * startTime = [NSDate new];
    NSData * dzlibCompressed = [myPayloaddata zlibDeflateWithDict:[dictString dataUsingEncoding:NSUTF8StringEncoding]];
    NSDate * dzTime = [NSDate new];
    //NSData * zlibCompressed = [myPayloaddata zlibDeflate];
    //NSData * gzipCompressed = [myPayloaddata gzipDeflate];
    //NSData * gzipCompressed2 = [myPayloaddata gzippedData];
    NSData * dictCompressed = [myPayloaddata compressWithDict:dict];
    NSDate * dictTime = [NSDate new];
    NSTimeInterval dzElapsed = [dzTime timeIntervalSinceDate:startTime];
    NSTimeInterval dictElapsed = [dictTime timeIntervalSinceDate:dzTime];
    NSLog(@"Original payload        len: %d", myPayloaddata.length);
    NSLog(@"dzlibCompressed payload len: %d, (%2.1f%%) time %0.2f ms", dzlibCompressed.length, (double)dzlibCompressed.length / (double)myPayloaddata.length * 100.0, dzElapsed*1000);
    NSLog(@"dictCompressed payload  len: %d, (%2.1f%%) time %0.2f ms", dictCompressed.length, (double)dictCompressed.length / (double)myPayloaddata.length * 100.0, dictElapsed*1000);
    //NSLog(@"zlibCompressed payload  len: %d, (%2.1f%%)", zlibCompressed.length, (double)zlibCompressed.length / (double)myPayloaddata.length * 100.0);
    //NSLog(@"gzipCompressed payload  len: %d, (%2.1f%%)", gzipCompressed.length, (double)gzipCompressed.length / (double)myPayloaddata.length * 100.0);
    //NSLog(@"gzipCompressed2 payload len: %d, (%2.1f%%)", gzipCompressed2.length, (double)gzipCompressed2.length / (double)myPayloaddata.length * 100.0);
    NSLog(@"\n");
    
}
#endif

- (BOOL) sendJson: (NSDictionary*) jsonObject {
    NSData * myPayloaddata = [NSJSONSerialization dataWithJSONObject: jsonObject options: 0 error: nil];
    NSString * myPayloadString = [[NSString alloc] initWithData:myPayloaddata encoding:NSUTF8StringEncoding];
    if ([[self verbosityLevel]isEqualToString:@"dump"]) {
        NSLog(@"JSON SEND->: %@",myPayloadString);
#ifdef TEST_COMPRESSION
        [self testCompression:myPayloaddata];
#endif
    }
    if (_websocket.readyState == SR_OPEN) {
        [_websocket send: myPayloadString];
        if ([self.delegate respondsToSelector:@selector(webSocket:didSendWithOpenRequests:)]) {
            [self.delegate webSocket:_websocket didSendWithOpenRequests:_responseHandlers.count];
        }
        return YES;
    } else {
        NSLog(@"sendJson: sending failed, connection not open");
    }
    return NO;
}

- (NSNumber*) nextId {
    return @(_id++);
}

- (void) flushOpenRequests {
    NSLog(@"JsonRpc: connection was closed,  flushing %d open requests", (int)_responseHandlers.count);
    _flushedRequests = _responseHandlers.count;
    NSArray * allResponses = [_responseHandlers allKeys];
    for (id key in allResponses) {
        NSNumber * theKey = key;
        NSDictionary * request = _responseHandlers[theKey];
        [_responseHandlers removeObjectForKey: theKey];
        ResponseBlock handler = request[@"handler"];
        NSTimer * timer = request[@"timer"];
        [timer invalidate];
        NSLog(@"JsonRpc: request %@ was flushed (connection was closed)", theKey);
        handler(@{@"message":@"connection closed",@"code":@7003}, NO);
    }
    
}

- (void) droppedRequest: (NSNumber*) jsonRpcId {
    NSLog(@"JsonRpc: request %@ was dropped (no connection)", jsonRpcId);
    NSDictionary * responseHandler = _responseHandlers[jsonRpcId];
    if (responseHandler != nil) {
        [_responseHandlers removeObjectForKey: jsonRpcId];
        ResponseBlock handler = responseHandler[@"handler"];
        NSTimer * timer = responseHandler[@"timer"];
        [timer invalidate];
        handler(@{@"message":@"request dropped",@"code":@7001}, NO);
    }
}

- (void) serverDidNotRespond: (NSTimer*) jsonRequestTimer {
    NSNumber * jsonRpcId = jsonRequestTimer.userInfo;
    NSLog(@"Server did not respond within %f seconds, request %@ was dropped", kResponseTimeout, jsonRpcId);
    NSDictionary * responseHandler = _responseHandlers[jsonRpcId];
    if (responseHandler != nil) {
        ResponseBlock handler = responseHandler[@"handler"];
        [_responseHandlers removeObjectForKey: jsonRpcId];
        handler(@{@"message":@"request timeout",@"code":@7002}, NO);
    } else {
        NSLog(@"No response handler for request %@, timeout ignored",jsonRpcId);
    }
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

+ (JsonRpcHandler*) jsonRpcHanlder: (SEL) selector isNotification: (BOOL) notificationFlag asyncResult:(BOOL)asyncResultFlag {
    JsonRpcHandler * handler = [[JsonRpcHandler alloc] init];
    handler.selector = selector;
    handler.isNotification = notificationFlag;
    handler.asyncResult = asyncResultFlag;
    return handler;
}



@end

