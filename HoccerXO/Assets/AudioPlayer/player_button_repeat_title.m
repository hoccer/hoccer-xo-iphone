//
//  player_button_repeat_title.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_repeat_title.h"

@implementation player_button_repeat_title

- (void)initPath {

    [self.path moveToPoint: CGPointMake(27.06, 16.18)];
    [self.path addCurveToPoint: CGPointMake(20.12, 9.18) controlPoint1: CGPointMake(23.14, 16.18) controlPoint2: CGPointMake(20.12, 12.95)];
    [self.path addCurveToPoint: CGPointMake(27.06, 2) controlPoint1: CGPointMake(20.12, 5.41) controlPoint2: CGPointMake(23.14, 2)];
    [self.path addCurveToPoint: CGPointMake(34, 9) controlPoint1: CGPointMake(30.97, 2) controlPoint2: CGPointMake(34, 5.23)];
    [self.path addCurveToPoint: CGPointMake(27.06, 16.18) controlPoint1: CGPointMake(34, 12.77) controlPoint2: CGPointMake(30.97, 16.18)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(28.13, 5.05)];
    [self.path addLineToPoint: CGPointMake(27.24, 5.05)];
    [self.path addCurveToPoint: CGPointMake(27.06, 5.59) controlPoint1: CGPointMake(27.24, 5.23) controlPoint2: CGPointMake(27.06, 5.59)];
    [self.path addCurveToPoint: CGPointMake(26.52, 5.95) controlPoint1: CGPointMake(26.88, 5.77) controlPoint2: CGPointMake(26.7, 5.95)];
    [self.path addCurveToPoint: CGPointMake(25.99, 6.13) controlPoint1: CGPointMake(26.35, 6.13) controlPoint2: CGPointMake(26.17, 6.13)];
    [self.path addCurveToPoint: CGPointMake(25.28, 6.13) controlPoint1: CGPointMake(25.81, 6.13) controlPoint2: CGPointMake(25.46, 6.13)];
    [self.path addLineToPoint: CGPointMake(25.28, 7.38)];
    [self.path addLineToPoint: CGPointMake(27.06, 7.38)];
    [self.path addLineToPoint: CGPointMake(27.06, 13.13)];
    [self.path addLineToPoint: CGPointMake(28.3, 13.13)];
    [self.path addLineToPoint: CGPointMake(28.3, 5.05)];
    [self.path addLineToPoint: CGPointMake(28.13, 5.05)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(11.04, 8.1)];
    [self.path addCurveToPoint: CGPointMake(3.92, 15.1) controlPoint1: CGPointMake(7.12, 8.1) controlPoint2: CGPointMake(3.92, 11.15)];
    [self.path addCurveToPoint: CGPointMake(3.92, 16) controlPoint1: CGPointMake(3.92, 15.46) controlPoint2: CGPointMake(3.92, 15.82)];
    [self.path addLineToPoint: CGPointMake(0.89, 19.41)];
    [self.path addCurveToPoint: CGPointMake(0, 15.1) controlPoint1: CGPointMake(0.36, 17.97) controlPoint2: CGPointMake(0, 16.54)];
    [self.path addCurveToPoint: CGPointMake(11.04, 3.97) controlPoint1: CGPointMake(0, 9) controlPoint2: CGPointMake(4.98, 3.97)];
    [self.path addLineToPoint: CGPointMake(19.58, 3.97)];
    [self.path addCurveToPoint: CGPointMake(18.16, 7.92) controlPoint1: CGPointMake(18.87, 5.23) controlPoint2: CGPointMake(18.34, 6.49)];
    [self.path addLineToPoint: CGPointMake(11.04, 7.92)];
    [self.path addLineToPoint: CGPointMake(11.04, 8.1)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(11.93, 22.1)];
    [self.path addLineToPoint: CGPointMake(21.01, 22.1)];
    [self.path addCurveToPoint: CGPointMake(27.41, 17.97) controlPoint1: CGPointMake(23.85, 22.1) controlPoint2: CGPointMake(26.17, 20.49)];
    [self.path addCurveToPoint: CGPointMake(32.04, 16.54) controlPoint1: CGPointMake(29.02, 17.97) controlPoint2: CGPointMake(30.62, 17.44)];
    [self.path addCurveToPoint: CGPointMake(21.18, 26.05) controlPoint1: CGPointMake(31.33, 21.92) controlPoint2: CGPointMake(26.7, 26.05)];
    [self.path addLineToPoint: CGPointMake(11.93, 26.05)];
    [self.path addLineToPoint: CGPointMake(11.93, 30)];
    [self.path addLineToPoint: CGPointMake(2.85, 23.9)];
    [self.path addLineToPoint: CGPointMake(11.93, 18.15)];
    [self.path addLineToPoint: CGPointMake(11.93, 22.1)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];

}

@end
