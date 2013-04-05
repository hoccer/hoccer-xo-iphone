//
//  NSManagedObject+RPCDictionary.m
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HoccerTalkModel.h"

@implementation HoccerTalkModel

+ (NSString*) entityName {
    return NSStringFromClass(self);
}

- (NSMutableDictionary*) rpcDictionary {
    NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
    NSDictionary * rpcKeys = [self rpcKeys];
    for (id key in rpcKeys) {
        if ([self valueForKeyPath: rpcKeys[key]] != nil) {
            dictionary[key] = [self valueForKeyPath: rpcKeys[key]];
        }
    }
    return dictionary;
}

- (void) updateWithDictionary: (NSDictionary*) dict {
    NSDictionary * rpcKeys = [self rpcKeys];
    //NSLog(@"Updatig object of type %@", NSStringFromClass([self class]));
    for (id key in dict) {
        if (rpcKeys[key] == nil) {
            NSLog(@"unhandled key '%@' in update dictionary", key);
            continue;
        }
        if ( ! [dict[key] isEqualToString: [self valueForKeyPath: rpcKeys[key]]]) {
            //NSLog(@"updating value for key '%@'", key);
            [self setValue: dict[key] forKeyPath: rpcKeys[key]];
        }
    }
}

- (NSDictionary*) rpcKeys { return @{}; }

@end
