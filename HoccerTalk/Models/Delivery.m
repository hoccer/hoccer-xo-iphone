//
//  Delivery.m
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Delivery.h"
#import "Message.h"


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


+ (NSString*) stateNew        { return @"new";        }
+ (NSString*) stateDelivering { return @"delivering"; }
+ (NSString*) stateDelivered  { return @"delivered";  }
+ (NSString*) stateFailed     { return @"failed";     }


@end
