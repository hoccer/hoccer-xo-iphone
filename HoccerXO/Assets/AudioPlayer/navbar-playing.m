//
//  navbar-playing.m
//  HoccerXO
//
//  Created by Peter Amende on 04.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "navbar-playing.h"

@implementation navbar_playing

- (void)initPath {

    [self.path moveToPoint: CGPointMake(8.98, 10.49)];
    [self.path addLineToPoint: CGPointMake(8.98, 10.49)];
    [self.path addLineToPoint: CGPointMake(8.98, 15.73)];
    [self.path addCurveToPoint: CGPointMake(7.64, 15.56) controlPoint1: CGPointMake(8.62, 15.47) controlPoint2: CGPointMake(8.18, 15.38)];
    [self.path addCurveToPoint: CGPointMake(6.49, 17.42) controlPoint1: CGPointMake(6.84, 15.82) controlPoint2: CGPointMake(6.31, 16.71)];
    [self.path addCurveToPoint: CGPointMake(8.27, 18.4) controlPoint1: CGPointMake(6.67, 18.22) controlPoint2: CGPointMake(7.47, 18.67)];
    [self.path addCurveToPoint: CGPointMake(9.42, 16.53) controlPoint1: CGPointMake(9.07, 18.13) controlPoint2: CGPointMake(9.6, 17.24)];
    [self.path addLineToPoint: CGPointMake(9.42, 16.53)];
    [self.path addLineToPoint: CGPointMake(9.42, 16.53)];
    [self.path addLineToPoint: CGPointMake(9.42, 10.4)];
    [self.path addLineToPoint: CGPointMake(16, 8.71)];
    [self.path addLineToPoint: CGPointMake(16, 13.78)];
    [self.path addCurveToPoint: CGPointMake(14.67, 13.6) controlPoint1: CGPointMake(15.64, 13.51) controlPoint2: CGPointMake(15.2, 13.42)];
    [self.path addCurveToPoint: CGPointMake(13.51, 15.47) controlPoint1: CGPointMake(13.87, 13.87) controlPoint2: CGPointMake(13.33, 14.76)];
    [self.path addCurveToPoint: CGPointMake(15.29, 16.44) controlPoint1: CGPointMake(13.69, 16.27) controlPoint2: CGPointMake(14.49, 16.71)];
    [self.path addCurveToPoint: CGPointMake(16.44, 15.02) controlPoint1: CGPointMake(15.91, 16.27) controlPoint2: CGPointMake(16.36, 15.64)];
    [self.path addLineToPoint: CGPointMake(16.44, 15.02)];
    [self.path addLineToPoint: CGPointMake(16.44, 14.84)];
    [self.path addLineToPoint: CGPointMake(16.44, 14.84)];
    [self.path addLineToPoint: CGPointMake(16.44, 8.62)];
    [self.path addLineToPoint: CGPointMake(16.44, 8.62)];
    [self.path addLineToPoint: CGPointMake(16.44, 5.51)];
    [self.path addLineToPoint: CGPointMake(8.98, 7.47)];
    [self.path addLineToPoint: CGPointMake(8.98, 10.49)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(12, 0)];
    [self.path addCurveToPoint: CGPointMake(0, 12) controlPoint1: CGPointMake(5.33, 0) controlPoint2: CGPointMake(0, 5.33)];
    [self.path addCurveToPoint: CGPointMake(12, 24) controlPoint1: CGPointMake(0, 18.67) controlPoint2: CGPointMake(5.33, 24)];
    [self.path addCurveToPoint: CGPointMake(24, 12) controlPoint1: CGPointMake(18.67, 24) controlPoint2: CGPointMake(24, 18.67)];
    [self.path addCurveToPoint: CGPointMake(12, 0) controlPoint1: CGPointMake(24, 5.33) controlPoint2: CGPointMake(18.67, 0)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(12, 23.47)];
    [self.path addCurveToPoint: CGPointMake(0.53, 12) controlPoint1: CGPointMake(5.69, 23.47) controlPoint2: CGPointMake(0.53, 18.31)];
    [self.path addCurveToPoint: CGPointMake(12, 0.53) controlPoint1: CGPointMake(0.53, 5.69) controlPoint2: CGPointMake(5.69, 0.53)];
    [self.path addCurveToPoint: CGPointMake(23.47, 12) controlPoint1: CGPointMake(18.31, 0.53) controlPoint2: CGPointMake(23.47, 5.69)];
    [self.path addCurveToPoint: CGPointMake(12, 23.47) controlPoint1: CGPointMake(23.47, 18.31) controlPoint2: CGPointMake(18.31, 23.47)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];
    
}

@end
