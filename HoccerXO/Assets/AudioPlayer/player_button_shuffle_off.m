//
//  player_button_shuffle_off.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_shuffle_off.h"

@implementation player_button_shuffle_off

- (void)initPath {

    [self.path moveToPoint: CGPointMake(25.96, 9.01)];
    [self.path addLineToPoint: CGPointMake(22.4, 9.01)];
    [self.path addLineToPoint: CGPointMake(6.76, 24.78)];
    [self.path addCurveToPoint: CGPointMake(6.4, 24.96) controlPoint1: CGPointMake(6.58, 24.96) controlPoint2: CGPointMake(6.58, 24.96)];
    [self.path addCurveToPoint: CGPointMake(5.87, 24.96) controlPoint1: CGPointMake(6.22, 24.96) controlPoint2: CGPointMake(6.04, 24.96)];
    [self.path addLineToPoint: CGPointMake(1.07, 24.96)];
    [self.path addCurveToPoint: CGPointMake(0, 23.88) controlPoint1: CGPointMake(0.53, 24.96) controlPoint2: CGPointMake(0, 24.42)];
    [self.path addCurveToPoint: CGPointMake(1.07, 22.81) controlPoint1: CGPointMake(0, 23.34) controlPoint2: CGPointMake(0.53, 22.81)];
    [self.path addLineToPoint: CGPointMake(5.69, 22.81)];
    [self.path addLineToPoint: CGPointMake(21.33, 7.4)];
    [self.path addCurveToPoint: CGPointMake(22.04, 7.04) controlPoint1: CGPointMake(21.51, 7.22) controlPoint2: CGPointMake(21.69, 7.04)];
    [self.path addLineToPoint: CGPointMake(26.13, 7.04)];
    [self.path addLineToPoint: CGPointMake(26.13, 4)];
    [self.path addLineToPoint: CGPointMake(32, 7.94)];
    [self.path addLineToPoint: CGPointMake(25.96, 11.88)];
    [self.path addLineToPoint: CGPointMake(25.96, 9.01)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(5.69, 9.01)];
    [self.path addLineToPoint: CGPointMake(1.07, 9.01)];
    [self.path addCurveToPoint: CGPointMake(0, 7.94) controlPoint1: CGPointMake(0.53, 9.01) controlPoint2: CGPointMake(0, 8.66)];
    [self.path addCurveToPoint: CGPointMake(1.07, 6.87) controlPoint1: CGPointMake(0, 7.4) controlPoint2: CGPointMake(0.53, 6.87)];
    [self.path addLineToPoint: CGPointMake(6.04, 6.87)];
    [self.path addCurveToPoint: CGPointMake(6.58, 6.87) controlPoint1: CGPointMake(6.22, 6.87) controlPoint2: CGPointMake(6.4, 6.87)];
    [self.path addCurveToPoint: CGPointMake(6.93, 7.04) controlPoint1: CGPointMake(6.76, 6.87) controlPoint2: CGPointMake(6.76, 7.04)];
    [self.path addLineToPoint: CGPointMake(12.98, 13.13)];
    [self.path addLineToPoint: CGPointMake(11.38, 14.75)];
    [self.path addLineToPoint: CGPointMake(5.69, 9.01)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(22.4, 23.16)];
    [self.path addLineToPoint: CGPointMake(25.96, 23.16)];
    [self.path addLineToPoint: CGPointMake(25.96, 20.12)];
    [self.path addLineToPoint: CGPointMake(32, 24.06)];
    [self.path addLineToPoint: CGPointMake(25.96, 28)];
    [self.path addLineToPoint: CGPointMake(25.96, 24.96)];
    [self.path addLineToPoint: CGPointMake(21.87, 24.96)];
    [self.path addCurveToPoint: CGPointMake(21.16, 24.6) controlPoint1: CGPointMake(21.51, 24.96) controlPoint2: CGPointMake(21.33, 24.78)];
    [self.path addLineToPoint: CGPointMake(15.29, 18.87)];
    [self.path addLineToPoint: CGPointMake(16.71, 17.43)];
    [self.path addLineToPoint: CGPointMake(22.4, 23.16)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];
    
}

@end
