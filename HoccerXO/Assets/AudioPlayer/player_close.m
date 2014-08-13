//
//  player_close.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_close.h"

@implementation player_close

- (void)initPath {

    [self.path moveToPoint: CGPointMake(19.36, 16.07)];
    [self.path addLineToPoint: CGPointMake(31.79, 28.45)];
    [self.path addCurveToPoint: CGPointMake(31.79, 29.57) controlPoint1: CGPointMake(32.07, 28.73) controlPoint2: CGPointMake(32.07, 29.29)];
    [self.path addLineToPoint: CGPointMake(29.5, 31.79)];
    [self.path addCurveToPoint: CGPointMake(28.36, 31.79) controlPoint1: CGPointMake(29.21, 32.07) controlPoint2: CGPointMake(28.64, 32.07)];
    [self.path addLineToPoint: CGPointMake(16.07, 19.55)];
    [self.path addLineToPoint: CGPointMake(3.64, 31.79)];
    [self.path addCurveToPoint: CGPointMake(2.5, 31.79) controlPoint1: CGPointMake(3.21, 32.07) controlPoint2: CGPointMake(2.79, 32.07)];
    [self.path addLineToPoint: CGPointMake(0.21, 29.57)];
    [self.path addCurveToPoint: CGPointMake(0.21, 28.45) controlPoint1: CGPointMake(-0.07, 29.29) controlPoint2: CGPointMake(-0.07, 28.73)];
    [self.path addLineToPoint: CGPointMake(12.64, 16.07)];
    [self.path addLineToPoint: CGPointMake(0.21, 3.55)];
    [self.path addCurveToPoint: CGPointMake(0.21, 2.43) controlPoint1: CGPointMake(-0.07, 3.27) controlPoint2: CGPointMake(-0.07, 2.85)];
    [self.path addLineToPoint: CGPointMake(2.5, 0.21)];
    [self.path addCurveToPoint: CGPointMake(3.64, 0.21) controlPoint1: CGPointMake(2.79, -0.07) controlPoint2: CGPointMake(3.36, -0.07)];
    [self.path addLineToPoint: CGPointMake(15.93, 12.73)];
    [self.path addLineToPoint: CGPointMake(28.21, 0.21)];
    [self.path addCurveToPoint: CGPointMake(29.36, 0.21) controlPoint1: CGPointMake(28.5, -0.07) controlPoint2: CGPointMake(29.07, -0.07)];
    [self.path addLineToPoint: CGPointMake(31.64, 2.43)];
    [self.path addCurveToPoint: CGPointMake(31.64, 3.55) controlPoint1: CGPointMake(31.93, 2.71) controlPoint2: CGPointMake(31.93, 3.27)];
    [self.path addLineToPoint: CGPointMake(19.36, 16.07)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];
    
}

@end
