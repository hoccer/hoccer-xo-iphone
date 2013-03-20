//
//  NSManagedObject+RPCDictionary.m
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NSManagedObject+RPCDictionary.h"

@implementation NSManagedObject (RPCDictionary)

- (NSMutableDictionary*) rpcDictionary {
    /*
    NSEntityDescription * entity = [self entity];
    NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
    for (NSPropertyDescription * property in entity) {
        if (property.userInfo[@"RPCProperty"] != nil) {
            if ([property isKindOfClass: [NSRelationshipDescription class]]) {

            } else if ([property isKindOfClass: [NSAttributeDescription class]]) {
                dictionary[property.name] = [self valueForKey: property.name];
            }
        }
    }
    return dictionary;
     */
    NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
    NSDictionary * rpcKeys = [self rpcKeys];
    for (id key in rpcKeys) {
        dictionary[key] = [self valueForKeyPath: rpcKeys[key]];
    }
    return dictionary;
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

- (NSDictionary*) rpcKeys { return @{}; }
@end
