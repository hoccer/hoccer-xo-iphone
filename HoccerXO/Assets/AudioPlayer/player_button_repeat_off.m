//
//  player_button_repeat_off.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_repeat_off.h"

@implementation player_button_repeat_off

- (void)initPath {

    [self.path moveToPoint: CGPointMake(21, 25.97)];
    [self.path addLineToPoint: CGPointMake(11, 25.97)];
    [self.path addLineToPoint: CGPointMake(11, 25.97)];
    [self.path addLineToPoint: CGPointMake(11, 29)];
    [self.path addLineToPoint: CGPointMake(4.93, 24.9)];
    [self.path addLineToPoint: CGPointMake(11, 20.81)];
    [self.path addLineToPoint: CGPointMake(11, 23.84)];
    [self.path addLineToPoint: CGPointMake(11, 23.84)];
    [self.path addLineToPoint: CGPointMake(21, 23.84)];
    [self.path addCurveToPoint: CGPointMake(29.03, 15.82) controlPoint1: CGPointMake(25.46, 23.84) controlPoint2: CGPointMake(29.03, 20.27)];
    [self.path addCurveToPoint: CGPointMake(27.6, 11.19) controlPoint1: CGPointMake(29.03, 14.04) controlPoint2: CGPointMake(28.5, 12.62)];
    [self.path addLineToPoint: CGPointMake(29.03, 9.77)];
    [self.path addCurveToPoint: CGPointMake(30.99, 15.82) controlPoint1: CGPointMake(30.28, 11.37) controlPoint2: CGPointMake(30.99, 13.51)];
    [self.path addCurveToPoint: CGPointMake(21, 25.97) controlPoint1: CGPointMake(31.17, 21.52) controlPoint2: CGPointMake(26.71, 25.97)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(21.18, 7.99)];
    [self.path addLineToPoint: CGPointMake(21.18, 7.99)];
    [self.path addLineToPoint: CGPointMake(11.18, 7.99)];
    [self.path addCurveToPoint: CGPointMake(3.14, 16) controlPoint1: CGPointMake(6.71, 7.99) controlPoint2: CGPointMake(3.14, 11.55)];
    [self.path addCurveToPoint: CGPointMake(4.57, 20.63) controlPoint1: CGPointMake(3.14, 17.78) controlPoint2: CGPointMake(3.68, 19.21)];
    [self.path addLineToPoint: CGPointMake(3.14, 22.05)];
    [self.path addCurveToPoint: CGPointMake(1, 16) controlPoint1: CGPointMake(1.71, 20.27) controlPoint2: CGPointMake(1, 18.32)];
    [self.path addCurveToPoint: CGPointMake(11, 6.03) controlPoint1: CGPointMake(1, 10.48) controlPoint2: CGPointMake(5.46, 6.03)];
    [self.path addLineToPoint: CGPointMake(21, 6.03)];
    [self.path addLineToPoint: CGPointMake(21, 6.03)];
    [self.path addLineToPoint: CGPointMake(21, 3)];
    [self.path addLineToPoint: CGPointMake(27.07, 7.1)];
    [self.path addLineToPoint: CGPointMake(21, 11.19)];
    [self.path addLineToPoint: CGPointMake(21, 7.99)];
    [self.path addLineToPoint: CGPointMake(21.18, 7.99)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];

}

@end
