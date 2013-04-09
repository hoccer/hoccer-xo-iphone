//
//  Delivery.m
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Delivery.h"
#import "TalkMessage.h"

NSString * const kDeliveryStateNew        = @"new";
NSString * const kDeliveryStateDelivering = @"delivering";
NSString * const kDeliverySatteDevilered  = @"delivered";
NSString * const kDeliveryStateFailed     = @"failed";

@implementation Delivery

@dynamic state;
@dynamic message;
@dynamic receiver;

- (NSDictionary*) rpcKeys {
    return @{ @"state"     : @"state",
              @"receiverId": @"receiver.clientId",
              @"messageTag": @"message.messageTag",
              @"messageId" : @"message.messageId"
              };
}

@end
