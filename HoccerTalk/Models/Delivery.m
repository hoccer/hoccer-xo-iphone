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

- (void) updateWithDictionary: (NSDictionary*) dict {
    NSDictionary * rpcKeys = [self rpcKeys];
    for (id key in dict) {
        if (rpcKeys[key] == nil) {
            NSLog(@"unhandled key '%@' in update dictionary", key);
            continue;
        }
        if ( ! [dict[key] isEqualToString: [self valueForKeyPath: rpcKeys[key]]]) {
            NSLog(@"updating value for key '%@'", key);
            [self setValue: dict[key] forKeyPath: rpcKeys[key]];
        }
    }
}

+ (NSString*) stateNew        { return @"new";        }
+ (NSString*) stateDelivering { return @"delivering"; }
+ (NSString*) stateDelivered  { return @"delivered";  }
+ (NSString*) stateFailed     { return @"failed";     }


@end
