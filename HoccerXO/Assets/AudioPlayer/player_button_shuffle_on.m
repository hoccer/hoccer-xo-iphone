//
//  player_button_shuffle_on.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_shuffle_on.h"

@implementation player_button_shuffle_on

- (void)initPath {

    [self.path moveToPoint: CGPointMake(24.26, 9.97)];
    [self.path addLineToPoint: CGPointMake(22.19, 9.97)];
    [self.path addLineToPoint: CGPointMake(7.4, 25.22)];
    [self.path addCurveToPoint: CGPointMake(5.85, 25.92) controlPoint1: CGPointMake(7.05, 25.75) controlPoint2: CGPointMake(6.54, 25.92)];
    [self.path addLineToPoint: CGPointMake(1.89, 25.92)];
    [self.path addCurveToPoint: CGPointMake(0, 23.97) controlPoint1: CGPointMake(0.86, 25.92) controlPoint2: CGPointMake(0, 25.04)];
    [self.path addCurveToPoint: CGPointMake(1.89, 22.03) controlPoint1: CGPointMake(0, 22.91) controlPoint2: CGPointMake(0.86, 22.03)];
    [self.path addLineToPoint: CGPointMake(4.99, 22.03)];
    [self.path addLineToPoint: CGPointMake(19.78, 6.78)];
    [self.path addCurveToPoint: CGPointMake(20.65, 6.25) controlPoint1: CGPointMake(19.96, 6.43) controlPoint2: CGPointMake(20.3, 6.25)];
    [self.path addLineToPoint: CGPointMake(20.82, 6.25)];
    [self.path addCurveToPoint: CGPointMake(21.16, 6.25) controlPoint1: CGPointMake(20.99, 6.25) controlPoint2: CGPointMake(20.99, 6.25)];
    [self.path addCurveToPoint: CGPointMake(21.51, 6.25) controlPoint1: CGPointMake(21.33, 6.25) controlPoint2: CGPointMake(21.33, 6.25)];
    [self.path addLineToPoint: CGPointMake(24.26, 6.25)];
    [self.path addLineToPoint: CGPointMake(24.26, 2)];
    [self.path addLineToPoint: CGPointMake(32, 8.03)];
    [self.path addLineToPoint: CGPointMake(24.26, 14.05)];
    [self.path addLineToPoint: CGPointMake(24.26, 9.97)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(4.99, 9.97)];
    [self.path addLineToPoint: CGPointMake(1.89, 9.97)];
    [self.path addCurveToPoint: CGPointMake(0, 8.03) controlPoint1: CGPointMake(0.86, 9.97) controlPoint2: CGPointMake(0, 9.09)];
    [self.path addCurveToPoint: CGPointMake(1.89, 6.08) controlPoint1: CGPointMake(0, 6.96) controlPoint2: CGPointMake(0.86, 6.08)];
    [self.path addLineToPoint: CGPointMake(5.16, 6.08)];
    [self.path addCurveToPoint: CGPointMake(6.88, 6.43) controlPoint1: CGPointMake(5.68, 5.9) controlPoint2: CGPointMake(6.37, 6.08)];
    [self.path addCurveToPoint: CGPointMake(7.05, 6.43) controlPoint1: CGPointMake(6.88, 6.43) controlPoint2: CGPointMake(6.88, 6.43)];
    [self.path addLineToPoint: CGPointMake(7.23, 6.43)];
    [self.path addLineToPoint: CGPointMake(7.4, 6.61)];
    [self.path addLineToPoint: CGPointMake(7.4, 6.61)];
    [self.path addLineToPoint: CGPointMake(12.73, 12.1)];
    [self.path addLineToPoint: CGPointMake(9.81, 14.94)];
    [self.path addLineToPoint: CGPointMake(4.99, 9.97)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(22.02, 21.85)];
    [self.path addLineToPoint: CGPointMake(24.09, 21.85)];
    [self.path addLineToPoint: CGPointMake(24.09, 17.95)];
    [self.path addLineToPoint: CGPointMake(31.83, 23.97)];
    [self.path addLineToPoint: CGPointMake(24.09, 30)];
    [self.path addLineToPoint: CGPointMake(24.09, 26.1)];
    [self.path addLineToPoint: CGPointMake(21.85, 26.1)];
    [self.path addCurveToPoint: CGPointMake(20.13, 25.75) controlPoint1: CGPointMake(21.33, 26.28) controlPoint2: CGPointMake(20.65, 26.1)];
    [self.path addCurveToPoint: CGPointMake(19.96, 25.75) controlPoint1: CGPointMake(20.13, 25.75) controlPoint2: CGPointMake(20.13, 25.75)];
    [self.path addLineToPoint: CGPointMake(19.78, 25.75)];
    [self.path addLineToPoint: CGPointMake(19.61, 25.57)];
    [self.path addLineToPoint: CGPointMake(19.61, 25.57)];
    [self.path addLineToPoint: CGPointMake(14.28, 20.08)];
    [self.path addLineToPoint: CGPointMake(17.03, 17.24)];
    [self.path addLineToPoint: CGPointMake(22.02, 21.85)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];
    
}

@end
