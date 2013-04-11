//
//  Relationship.m
//  HoccerTalk
//
//  Created by David Siegel on 09.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Relationship.h"
#import "Contact.h"

NSString * const kRelationStateNone    = @"none";
NSString * const kRelationStateFriend  = @"friend";
NSString * const kRelationStateBlocked = @"blocked";

@implementation Relationship

@dynamic state;
@dynamic lastChanged;
@dynamic contact;

- (NSDictionary*) rpcKeys {
    return @{ @"state"     : @"state",
              @"lastChanged": @"lastChanged",
            };
}

- (void) setLastChanged:(id) time {
    if ([time isKindOfClass:[NSNumber class]]) {
        time = [NSDate dateWithTimeIntervalSince1970: [time doubleValue] / 1000.0];
    }
    [self willChangeValueForKey: @"lastChanged"];
    [self setPrimitiveValue: time forKey: @"lastChanged"];
    [self didChangeValueForKey: @"lastChanged"];
}

@end
