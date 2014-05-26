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
    NSInteger ti = (NSInteger)abs(round(interval));
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    
    NSString *sign = interval <= -0.5 ? @"-" : @"";
    
    if (hours > 0) {
        return [NSString stringWithFormat:@"%@%i:%02i:%02i", sign, hours, minutes, seconds];
    }
    
    return [NSString stringWithFormat:@"%@%i:%02i", sign, minutes, seconds];
}

@end
