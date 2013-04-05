//
//  HoccerTalkBackend.m
//  HoccerTalk
//
//  Created by David Siegel on 13.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HoccerTalkBackend.h"

#import "JsonRpcWebSocket.h"
#import "TalkMessage.h"
#import "Delivery.h"
#import "Contact.h"
#import "AppDelegate.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"


@interface HoccerTalkBackend ()
{
    JsonRpcWebSocket * _serverConnection;
    BOOL _isConnected;
    double _backoffTime;
    NSString * _apnsDeviceToken;
}

- (void) identify;

@end

@implementation HoccerTalkBackend

- (id) init {
    self = [super init];
    if (self != nil) {
        _backoffTime = 0.0;
        _isConnected = NO;
        _apnsDeviceToken = nil;
        _serverConnection = [[JsonRpcWebSocket alloc] initWithURLRequest: [self urlRequest]];
        _serverConnection.delegate = self;
        [_serverConnection registerIncomingCall: @"incomingDelivery" withSelector:@selector(incomingDelivery:) isNotification: YES];
    }
    return self;
}

// TODO: contact should be an array of contacts
- (TalkMessage*) sendMessage:(NSString *) text toContact: (Contact*) contact {
    TalkMessage * message =  (TalkMessage*)[NSEntityDescription insertNewObjectForEntityForName: [TalkMessage entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    message.body = text;
    message.timeStamp = [NSDate date];
    message.contact = contact;
    message.isOutgoing = @YES;
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    message.messageId = @"";
    message.messageTag = [NSString stringWithUUID];

    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    delivery.receiver = contact;

    contact.latestMessageTime = message.timeStamp;

    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];


    if (_isConnected) {
        [self deliveryRequest: message withDeliveries: @[delivery]];
    }
    return message;
}

- (void) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary {
    TalkMessage * message =  (TalkMessage*)[NSEntityDescription insertNewObjectForEntityForName: [TalkMessage entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName: [Delivery entityName] inManagedObjectContext: self.delegate.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;

    NSDictionary * vars = @{ @"clientId" : messageDictionary[@"senderId"]};
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestFromTemplateWithName:@"ContactByClientId" substitutionVariables: vars];
    NSError *error;
    NSArray *contacts = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (contacts == nil)
    {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Contact * contact = nil;
    // TODO: getr rid of this ...
    if (contacts.count > 0) {
        contact = contacts[0];
    } else {
        NSLog(@"Ignoring message from unknown clientId %@", messageDictionary[@"senderId"]);
        [self.delegate.managedObjectContext deleteObject: message];
        [self.delegate.managedObjectContext deleteObject: delivery];
        return;
    }

    [delivery updateWithDictionary: deliveryDictionary];

    // TODO: handle the actual message
    message.isOutgoing = @NO;
    message.isRead = @NO;
    message.timeStamp = [NSDate date]; // TODO: use actual timestamp
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    message.contact = contact;
    [contact.messages addObject: message];
    [message updateWithDictionary: messageDictionary];

    contact.latestMessageTime = message.timeStamp;

    [self.delegate.managedObjectContext refreshObject: contact mergeChanges: YES];
    [self deliveryConfirm: message.messageId withDelivery: delivery];
}

- (void) gotAPNSDeviceToken: (NSData*) deviceToken {
    // TODO: send device token to server
    _apnsDeviceToken = [deviceToken hexadecimalString];
    if (_isConnected) {
        [self registerApns: _apnsDeviceToken];
    }
}

- (void) start {
    [_serverConnection open];
}

- (void) reconnectWitBackoff {
    NSLog(@"reconnecting in %f seconds", _backoffTime);
    if (_backoffTime == 0) {
        [self reconnect];
        _backoffTime = (double)rand() / RAND_MAX;
    } else {
        [NSTimer scheduledTimerWithTimeInterval: _backoffTime target: self selector: @selector(reconnect) userInfo: nil repeats: NO];
        _backoffTime = MIN(2 * _backoffTime, 10);
    }
}

- (void) reconnect {
    [_serverConnection reopenWithURLRequest: [self urlRequest]];
}

- (NSURLRequest*) urlRequest {
    NSURL * url = [NSURL URLWithString: @"ws://development.hoccer.com:7000/"];
    return [[NSURLRequest alloc] initWithURL: url];
}

- (void) flushPendingMessages {
    // fetch all deliveries with state 'new'
    NSFetchRequest *fetchRequest = [self.delegate.managedObjectModel fetchRequestTemplateForName:@"DeliveriesWithStateNew"];
    NSError *error;
    NSArray *deliveries = [self.delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (deliveries == nil)
    {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    // collect all messages that have a delivery with state 'new'
    NSMutableSet * pendingMessages = [[NSMutableSet alloc] init];
    for (Delivery * delivery in deliveries) {
        if (! [pendingMessages containsObject: delivery.message]) {
            [pendingMessages addObject: delivery.message];
        }
    }
    // paranoid but safe: for each message collect those deliveries that have state 'new' and send them out
    for (TalkMessage * message in pendingMessages) {
        NSMutableArray * newDeliveries = [[NSMutableArray alloc] init];
        for (Delivery * delivery in message.deliveries) {
            if ([delivery.state isEqualToString: [Delivery stateNew]]) {
                [newDeliveries addObject: delivery];
            }
        }
        [self deliveryRequest: message withDeliveries: newDeliveries];
    }
}

#pragma mark - Outgoing RPC Calls

- (void) identify {
    NSString * clientId = [self.delegate clientId];
    NSLog(@"identify() clientId: %@", clientId);
    [_serverConnection invoke: @"identify" withParams: @[clientId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            _isConnected = YES;
            NSLog(@"identify(): got result: %@", responseOrError);
            [self flushPendingMessages];
            if (_apnsDeviceToken) {
                [self registerApns: _apnsDeviceToken];
            }
        } else {
            NSLog(@"identify(): got error: %@", responseOrError);
        }
    }];
}

- (void) deliveryRequest: (TalkMessage*) message withDeliveries: (NSArray*) deliveries {
    NSMutableDictionary * messageDict = [message rpcDictionary];
    NSMutableArray * deliveryDicts = [[NSMutableArray alloc] init];
    for (Delivery * delivery in deliveries) {
        [deliveryDicts addObject: [delivery rpcDictionary]];
    }
    NSLog(@"deliveryRequest: %@", messageDict);
    [_serverConnection invoke: @"deliveryRequest" withParams: @[messageDict, deliveryDicts] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"deliveryRequest() returned deliveries: %@", responseOrError);
            NSArray * updatedDeliveryDicts = (NSArray*)responseOrError;
            int i = 0;
            for (Delivery * delivery in deliveries) {
                [delivery updateWithDictionary: updatedDeliveryDicts[i++]];
            }
        } else {
            NSLog(@"deliveryRequest failed: %@", responseOrError);
        }
    }];
}

- (void) deliveryConfirm: (NSString*) messageId withDelivery: (Delivery*) delivery {
    NSLog(@"deliveryConfirm: %@", delivery);
    [_serverConnection invoke: @"deliveryConfirm" withParams: @[messageId] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"deliveryConfirm() returned deliveries: %@", responseOrError);
            [delivery updateWithDictionary: responseOrError];
        } else {
            NSLog(@"deliveryConfirm() failed: %@", responseOrError);
        }
    }];
}

- (void) registerApns: (NSString*) token {
    NSLog(@"registerApns: %@", token);
    [_serverConnection invoke: @"registerApns" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"registerApns(): got result: %@", responseOrError);
            _apnsDeviceToken = nil; // XXX: this is not nice...
        } else {
            // TODO retry?
            NSLog(@"registerApns(): failed: %@", responseOrError);
        }
    }];
}

- (void) generateToken: (NSString*) purpose validFor: (NSTimeInterval) seconds tokenHandler: (InviteTokenHanlder) handler {
    NSLog(@"generateToken:");
    [_serverConnection invoke: @"generateToken" withParams: @[purpose, [NSNumber numberWithInt:seconds]] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"generateToken(): got result: %@", responseOrError);
            handler(responseOrError);
        } else {
            NSLog(@"generateToken(): failed: %@", responseOrError);
            handler(nil);
        }
    }];
}

- (void) pairByToken: (NSString*) token pairingHandler: (PairingHandler) handler {
    NSLog(@"pairByToken:");
    [_serverConnection invoke: @"pairByToken" withParams: @[token] onResponse: ^(id responseOrError, BOOL success) {
        if (success) {
            NSLog(@"pairByToken(): got result: %@", responseOrError);
            handler([responseOrError boolValue]);
        } else {
            NSLog(@"pairByToken(): failed: %@", responseOrError);
            handler(NO);
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
    [self receiveMessage: messageDict withDelivery: deliveryDict];
}

- (void) outgoingDelivery: (NSArray*) params {
    /* TODO: implement outgoing delivery
    if (params.count != 1) {
        NSLog(@"outgoing requires an array of two parameters (delivery, message), but got %d parameters.", params.count);
        return;
    }
    if ( ! [params[0] isKindOfClass: [NSDictionary class]]) {
        return;
    }
    NSDictionary * deliveryDict = params[0];
     */
    NSLog(@"================= outgoingDelivery() called");
}

#pragma mark - JSON RPC WebSocket Delegate

- (void) webSocketDidFailWithError: (NSError*) error {
    NSLog(@"webSocketDidFailWithError: %@", error);
    _isConnected = NO;
    // if we get an error add a little initial backoff
    if (_backoffTime == 0) {
        _backoffTime = (double)rand() / RAND_MAX;
    }
    [self reconnectWitBackoff];
}

- (void) didReceiveInvalidJsonRpcMessage: (NSError*) error {
    NSLog(@"didReceiveInvalidJsonRpcMessage: %@", error);
}

- (void) webSocketDidOpen: (SRWebSocket*) webSocket {
    //NSLog(@"webSocketDidOpen");
    _backoffTime = 0.0;
    [self identify];
}

- (void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"webSocket didCloseWithCode %d reason: %@ clean: %d", code, reason, wasClean);
    _isConnected = NO;
    [self reconnectWitBackoff];
}

- (void) incomingMethodCallDidFail: (NSError*) error {
    NSLog(@"incoming JSON RPC method call failed: %@", error);
}

@end
