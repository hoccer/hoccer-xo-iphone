//
//  NSManagedObject+RPCDictionary.m
//  HoccerXO
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOModel.h"

#define OBJECT_DUMP NO

@implementation HXOModel

+ (NSString*) entityName {
    return NSStringFromClass(self);
}

- (NSMutableDictionary*) rpcDictionary {
    return [HXOModel createDictionaryFromObject:self withKeys:[self rpcKeys]];
}

+ (NSMutableDictionary*) createDictionaryFromObject:(id)object withKeys:(NSDictionary*)keys {
    NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
    for (id key in keys) {
        if (OBJECT_DUMP) {NSLog(@"createDictionaryFromObject key '%@' in new dictionary", key);}
        if ([object valueForKeyPath: keys[key]] != nil) {
            dictionary[key] = [object valueForKeyPath: keys[key]];
        }
    }
    return dictionary;
}

- (void) updateWithDictionary: (NSDictionary*) dict {
    [self updateWithDictionary:dict withKeys:[self rpcKeys]];
}

- (void) updateWithDictionary: (NSDictionary*) dict withKeys:(NSDictionary*)keys {
    [HXOModel updateObject:self withDictionary:dict withKeys:keys];
}

+ (void) updateObject:(id)object withDictionary: (NSDictionary*) dict withKeys:(NSDictionary*)keys {
    if (OBJECT_DUMP) {NSLog(@"Updatig object of type %@", NSStringFromClass([object class]));}
    for (id key in dict) {
        if (keys[key] == nil) {
            // NSLog(@"unhandled key '%@' in update dictionary, ignoring key:", key);
            continue;
        }
        if (OBJECT_DUMP) {NSLog(@"check value for key '%@'", key);}
        id oldValue = [object valueForKeyPath: keys[key]];
        if (OBJECT_DUMP) {NSLog(@"oldCoreDataValue = '%@'", oldValue);}
        id newIncomingValue = dict[key];
        if (OBJECT_DUMP) {NSLog(@"newIncomingValue = '%@'", newIncomingValue);}
        
        if ( ! [newIncomingValue isEqual: oldValue]) {
            if (OBJECT_DUMP) {NSLog(@"updating value for key '%@'", key);}
            [object setValue: newIncomingValue forKeyPath: keys[key]];
        }
    }
}

- (NSDictionary*) rpcKeys { return @{}; }

@end
