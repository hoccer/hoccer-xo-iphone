//
//  player_icon_volume_up.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_icon_volume_up.h"

@implementation player_icon_volume_up

- (void)initPath {

    [self.path moveToPoint: CGPointMake(25.23, 30)];
    [self.path addLineToPoint: CGPointMake(23.69, 27.87)];
    [self.path addCurveToPoint: CGPointMake(29.54, 15.85) controlPoint1: CGPointMake(27.23, 24.98) controlPoint2: CGPointMake(29.54, 20.72)];
    [self.path addCurveToPoint: CGPointMake(23.69, 3.83) controlPoint1: CGPointMake(29.54, 10.98) controlPoint2: CGPointMake(27.23, 6.72)];
    [self.path addLineToPoint: CGPointMake(25.23, 2)];
    [self.path addCurveToPoint: CGPointMake(32, 16) controlPoint1: CGPointMake(29.38, 5.35) controlPoint2: CGPointMake(32, 10.37)];
    [self.path addCurveToPoint: CGPointMake(25.23, 30) controlPoint1: CGPointMake(32, 21.63) controlPoint2: CGPointMake(29.38, 26.65)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(21.54, 25.28)];
    [self.path addLineToPoint: CGPointMake(19.85, 23.3)];
    [self.path addCurveToPoint: CGPointMake(23.38, 16) controlPoint1: CGPointMake(22, 21.63) controlPoint2: CGPointMake(23.38, 18.89)];
    [self.path addCurveToPoint: CGPointMake(19.85, 8.7) controlPoint1: CGPointMake(23.38, 13.11) controlPoint2: CGPointMake(22, 10.37)];
    [self.path addLineToPoint: CGPointMake(21.54, 6.72)];
    [self.path addCurveToPoint: CGPointMake(26, 16) controlPoint1: CGPointMake(24.31, 8.85) controlPoint2: CGPointMake(26, 12.2)];
    [self.path addCurveToPoint: CGPointMake(21.54, 25.28) controlPoint1: CGPointMake(26, 19.65) controlPoint2: CGPointMake(24.15, 23.15)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(1.69, 22.85)];
    [self.path addCurveToPoint: CGPointMake(0, 21.17) controlPoint1: CGPointMake(0.77, 22.85) controlPoint2: CGPointMake(0, 22.09)];
    [self.path addLineToPoint: CGPointMake(0, 10.83)];
    [self.path addCurveToPoint: CGPointMake(1.69, 9.15) controlPoint1: CGPointMake(0, 9.91) controlPoint2: CGPointMake(0.77, 9.15)];
    [self.path addLineToPoint: CGPointMake(8.31, 9.15)];
    [self.path addLineToPoint: CGPointMake(15.54, 3.22)];
    [self.path addLineToPoint: CGPointMake(15.54, 28.93)];
    [self.path addLineToPoint: CGPointMake(8.31, 23)];
    [self.path addLineToPoint: CGPointMake(1.69, 23)];
    [self.path addLineToPoint: CGPointMake(1.69, 22.85)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;

    self.fillColor = [UIColor whiteColor];
    
}

@end
