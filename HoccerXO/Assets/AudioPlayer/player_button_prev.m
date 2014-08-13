//
//  player_button_prev.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_prev.h"

@implementation player_button_prev

- (void)initPath {
    
    [self.path moveToPoint: CGPointMake(29.39, 0.57)];
    [self.path addCurveToPoint: CGPointMake(6.16, 14.77) controlPoint1: CGPointMake(27.97, 1.52) controlPoint2: CGPointMake(7.35, 13.83)];
    [self.path addCurveToPoint: CGPointMake(6.16, 17.85) controlPoint1: CGPointMake(4.98, 15.48) controlPoint2: CGPointMake(4.98, 17.14)];
    [self.path addCurveToPoint: CGPointMake(29.39, 32.05) controlPoint1: CGPointMake(7.82, 18.8) controlPoint2: CGPointMake(28.21, 31.34)];
    [self.path addCurveToPoint: CGPointMake(32, 30.63) controlPoint1: CGPointMake(30.58, 32.76) controlPoint2: CGPointMake(32, 31.82)];
    [self.path addLineToPoint: CGPointMake(32, 2.23)];
    [self.path addCurveToPoint: CGPointMake(29.39, 0.57) controlPoint1: CGPointMake(32, 0.57) controlPoint2: CGPointMake(30.58, -0.14)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(2.61, 0.33)];
    [self.path addCurveToPoint: CGPointMake(0, 2.94) controlPoint1: CGPointMake(1.19, 0.33) controlPoint2: CGPointMake(0, 1.52)];
    [self.path addLineToPoint: CGPointMake(0, 29.45)];
    [self.path addCurveToPoint: CGPointMake(2.61, 32.05) controlPoint1: CGPointMake(0, 30.87) controlPoint2: CGPointMake(1.19, 32.05)];
    [self.path addCurveToPoint: CGPointMake(5.21, 29.45) controlPoint1: CGPointMake(4.03, 32.05) controlPoint2: CGPointMake(5.21, 30.87)];
    [self.path addLineToPoint: CGPointMake(5.21, 2.94)];
    [self.path addCurveToPoint: CGPointMake(2.61, 0.33) controlPoint1: CGPointMake(5.45, 1.52) controlPoint2: CGPointMake(4.03, 0.33)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];

}

@end
