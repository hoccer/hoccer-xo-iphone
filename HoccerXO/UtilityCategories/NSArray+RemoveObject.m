//
//  NSArray+RemoveObject.m
//  HoccerXO
//
//  Created by Guido Lorenz on 11.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "NSArray+RemoveObject.h"

@implementation NSArray (RemoveObject)

- (NSArray *) arrayByRemovingObject:(id)object {
    if (!object) {
        return self;
    }

    NSMutableArray *mutableArray = [NSMutableArray arrayWithArray:self];
    [mutableArray removeObject:object];
    return mutableArray;
}

@end
