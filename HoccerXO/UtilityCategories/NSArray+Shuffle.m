//
//  NSArray+Shuffle.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 26/05/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "NSArray+Shuffle.h"

@implementation NSArray (Shuffling)

- (NSArray *)arrayByShuffling
{
    
    static BOOL seeded = NO;
    if(!seeded)
    {
        seeded = YES;
        srandom(time(NULL));
    }
    
    NSUInteger count = [self count];
    NSMutableArray *shuffledArray = [[NSMutableArray alloc] initWithCapacity: count];
    for (NSUInteger i = 0; i < count; ++i) {
        // Select a random element between i and end of array to swap with.
        int nElements = count - i;
        int n = (random() % nElements) + i;
        [shuffledArray exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
    return shuffledArray;
}

@end
