//
//  NSString+FromTimeInterval.m
//  HoccerXO
//
//  Created by Guido Lorenz on 13.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "NSString+FromTimeInterval.h"

@implementation NSString (FromTimeInterval)

+ (NSString *) stringFromTimeInterval: (NSTimeInterval)interval {
    long ti = labs(lround(interval));
    long seconds = ti % 60;
    long minutes = (ti / 60) % 60;
    long hours = (ti / 3600);
    
    NSString *sign = interval <= -0.5 ? @"-" : @"";
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%@%li:%02li:%02li", sign, hours, minutes, seconds];
    }
    
    return [NSString stringWithFormat:@"%@%li:%02li", sign, minutes, seconds];
}

@end
