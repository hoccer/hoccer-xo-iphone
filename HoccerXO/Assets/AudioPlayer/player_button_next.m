//
//  player_button_next.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_next.h"

@implementation player_button_next

- (void)initPath {

    [self.path moveToPoint: CGPointMake(2.61, 0.47)];
    [self.path addCurveToPoint: CGPointMake(0, 1.89) controlPoint1: CGPointMake(1.19, -0.47) controlPoint2: CGPointMake(0, 0.47)];
    [self.path addLineToPoint: CGPointMake(0, 30.3)];
    [self.path addCurveToPoint: CGPointMake(2.61, 31.72) controlPoint1: CGPointMake(0, 31.72) controlPoint2: CGPointMake(1.42, 32.43)];
    [self.path addCurveToPoint: CGPointMake(25.84, 17.52) controlPoint1: CGPointMake(4.03, 30.77) controlPoint2: CGPointMake(24.65, 18.46)];
    [self.path addCurveToPoint: CGPointMake(25.84, 14.44) controlPoint1: CGPointMake(27.02, 16.81) controlPoint2: CGPointMake(27.02, 15.15)];
    [self.path addCurveToPoint: CGPointMake(2.61, 0.47) controlPoint1: CGPointMake(23.94, 13.49) controlPoint2: CGPointMake(3.56, 0.95)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(29.39, 0)];
    [self.path addCurveToPoint: CGPointMake(26.79, 2.6) controlPoint1: CGPointMake(27.97, 0) controlPoint2: CGPointMake(26.79, 1.18)];
    [self.path addLineToPoint: CGPointMake(26.79, 29.12)];
    [self.path addCurveToPoint: CGPointMake(29.39, 31.72) controlPoint1: CGPointMake(26.79, 30.54) controlPoint2: CGPointMake(27.97, 31.72)];
    [self.path addCurveToPoint: CGPointMake(32, 29.12) controlPoint1: CGPointMake(30.81, 31.72) controlPoint2: CGPointMake(32, 30.54)];
    [self.path addLineToPoint: CGPointMake(32, 2.6)];
    [self.path addCurveToPoint: CGPointMake(29.39, 0) controlPoint1: CGPointMake(32, 1.18) controlPoint2: CGPointMake(30.81, 0)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];

}

@end
