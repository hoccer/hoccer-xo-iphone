//
//  player_button_repeat_all.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_repeat_all.h"

@implementation player_button_repeat_all

- (void)initPath {
    
    [self.path moveToPoint: CGPointMake(20.98, 27.07)];
    [self.path addLineToPoint: CGPointMake(11.91, 27.07)];
    [self.path addLineToPoint: CGPointMake(11.91, 31)];
    [self.path addLineToPoint: CGPointMake(2.84, 24.93)];
    [self.path addLineToPoint: CGPointMake(11.91, 18.86)];
    [self.path addLineToPoint: CGPointMake(11.91, 22.96)];
    [self.path addLineToPoint: CGPointMake(20.98, 22.96)];
    [self.path addCurveToPoint: CGPointMake(27.91, 16) controlPoint1: CGPointMake(24.89, 22.96) controlPoint2: CGPointMake(27.91, 19.75)];
    [self.path addCurveToPoint: CGPointMake(27.73, 15.11) controlPoint1: CGPointMake(27.91, 15.64) controlPoint2: CGPointMake(27.91, 15.46)];
    [self.path addLineToPoint: CGPointMake(30.93, 11.89)];
    [self.path addCurveToPoint: CGPointMake(32, 16) controlPoint1: CGPointMake(31.64, 13.14) controlPoint2: CGPointMake(32, 14.57)];
    [self.path addCurveToPoint: CGPointMake(20.98, 27.07) controlPoint1: CGPointMake(32, 22.25) controlPoint2: CGPointMake(27.02, 27.07)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(20.09, 9.04)];
    [self.path addLineToPoint: CGPointMake(11.02, 9.04)];
    [self.path addCurveToPoint: CGPointMake(4.09, 16) controlPoint1: CGPointMake(7.11, 9.04) controlPoint2: CGPointMake(4.09, 12.25)];
    [self.path addCurveToPoint: CGPointMake(4.27, 16.89) controlPoint1: CGPointMake(4.09, 16.36) controlPoint2: CGPointMake(4.09, 16.54)];
    [self.path addLineToPoint: CGPointMake(1.07, 20.11)];
    [self.path addCurveToPoint: CGPointMake(0, 16) controlPoint1: CGPointMake(0.36, 19.04) controlPoint2: CGPointMake(0, 17.61)];
    [self.path addCurveToPoint: CGPointMake(11.02, 4.93) controlPoint1: CGPointMake(0, 9.93) controlPoint2: CGPointMake(4.98, 4.93)];
    [self.path addLineToPoint: CGPointMake(20.09, 4.93)];
    [self.path addLineToPoint: CGPointMake(20.09, 1)];
    [self.path addLineToPoint: CGPointMake(29.16, 7.07)];
    [self.path addLineToPoint: CGPointMake(20.09, 13.14)];
    [self.path addLineToPoint: CGPointMake(20.09, 9.04)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];

}

@end
