//
//  NSString+EnumerateRanges.m
//  HoccerXO
//
//  Created by Guido Lorenz on 09.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "NSString+EnumerateRanges.h"

@implementation NSString (EnumerateRanges)

- (void) enumerateRangesOfString:(NSString *)string options:(NSStringCompareOptions)options usingBlock:(void (^)(NSRange range))block {
    BOOL done = NO;
    NSRange searchRange = NSMakeRange(0, [self length]);
    
    while (!done) {
        NSRange foundRange = [self rangeOfString:string options:options range:searchRange];
        
        if (foundRange.location == NSNotFound) {
            done = YES;
        } else {
            block(foundRange);
            
            NSUInteger newRangeStart = NSMaxRange(foundRange);
            searchRange = NSMakeRange(newRangeStart, [self length] - newRangeStart);
        }
    }
}

@end
