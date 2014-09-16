//
//  NSMutableArray+Shuffle.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 26/05/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "NSMutableArray+Shuffle.h"

@implementation NSMutableArray (Shuffling)

- (void) shuffle
{
    for (NSUInteger i = 0; i < self.count - 1; ++i) {
        // Select a random element between i and end of array to swap with.
        NSUInteger n = random() % (self.count - i) + i;
        [self exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
}

@end
