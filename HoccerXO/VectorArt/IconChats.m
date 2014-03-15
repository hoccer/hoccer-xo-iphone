//
//  IconChats.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "IconChats.h"

@implementation IconChats

- (void) initPath {
    UIBezierPath * bezierPath = self.path;

    [bezierPath moveToPoint: CGPointMake(30.2, 18.36)];
    [bezierPath addCurveToPoint: CGPointMake(29.09, 21.86) controlPoint1: CGPointMake(30.2, 19.66) controlPoint2: CGPointMake(29.81, 20.85)];
    [bezierPath addLineToPoint: CGPointMake(29.87, 23.9)];
    [bezierPath addCurveToPoint: CGPointMake(29.09, 24.69) controlPoint1: CGPointMake(30.14, 24.63) controlPoint2: CGPointMake(29.81, 25.03)];
    [bezierPath addLineToPoint: CGPointMake(26.86, 23.78)];
    [bezierPath addCurveToPoint: CGPointMake(23.63, 24.58) controlPoint1: CGPointMake(25.91, 24.29) controlPoint2: CGPointMake(24.8, 24.58)];
    [bezierPath addCurveToPoint: CGPointMake(19.56, 23.22) controlPoint1: CGPointMake(22.06, 24.58) controlPoint2: CGPointMake(20.67, 24.07)];
    [bezierPath addCurveToPoint: CGPointMake(13.04, 24.86) controlPoint1: CGPointMake(17.66, 24.29) controlPoint2: CGPointMake(15.43, 24.86)];
    [bezierPath addCurveToPoint: CGPointMake(8.86, 24.18) controlPoint1: CGPointMake(11.59, 24.86) controlPoint2: CGPointMake(10.14, 24.63)];
    [bezierPath addCurveToPoint: CGPointMake(8.8, 24.18) controlPoint1: CGPointMake(8.86, 24.18) controlPoint2: CGPointMake(8.86, 24.18)];
    [bezierPath addLineToPoint: CGPointMake(3.01, 25.87)];
    [bezierPath addCurveToPoint: CGPointMake(1.17, 24.01) controlPoint1: CGPointMake(1.56, 26.27) controlPoint2: CGPointMake(0.78, 25.42)];
    [bezierPath addLineToPoint: CGPointMake(2.4, 19.6)];
    [bezierPath addCurveToPoint: CGPointMake(0, 12.43) controlPoint1: CGPointMake(0.89, 17.57) controlPoint2: CGPointMake(0, 15.14)];
    [bezierPath addCurveToPoint: CGPointMake(13.09, 0) controlPoint1: CGPointMake(0, 5.54) controlPoint2: CGPointMake(5.85, 0)];
    [bezierPath addCurveToPoint: CGPointMake(26.19, 12.43) controlPoint1: CGPointMake(20.34, 0) controlPoint2: CGPointMake(26.19, 5.54)];
    [bezierPath addCurveToPoint: CGPointMake(26.19, 12.6) controlPoint1: CGPointMake(26.19, 12.49) controlPoint2: CGPointMake(26.19, 12.54)];
    [bezierPath addCurveToPoint: CGPointMake(30.2, 18.36) controlPoint1: CGPointMake(28.53, 13.56) controlPoint2: CGPointMake(30.2, 15.76)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(13.09, 1.13)];
    [bezierPath addCurveToPoint: CGPointMake(1.11, 12.43) controlPoint1: CGPointMake(6.46, 1.13) controlPoint2: CGPointMake(1.11, 6.21)];
    [bezierPath addCurveToPoint: CGPointMake(3.57, 19.26) controlPoint1: CGPointMake(1.11, 15.03) controlPoint2: CGPointMake(2.06, 17.4)];
    [bezierPath addLineToPoint: CGPointMake(2.28, 23.9)];
    [bezierPath addCurveToPoint: CGPointMake(3.18, 24.8) controlPoint1: CGPointMake(2.12, 24.58) controlPoint2: CGPointMake(2.51, 24.97)];
    [bezierPath addLineToPoint: CGPointMake(9.14, 23.05)];
    [bezierPath addCurveToPoint: CGPointMake(13.09, 23.67) controlPoint1: CGPointMake(10.36, 23.45) controlPoint2: CGPointMake(11.7, 23.67)];
    [bezierPath addCurveToPoint: CGPointMake(18.72, 22.37) controlPoint1: CGPointMake(15.16, 23.67) controlPoint2: CGPointMake(17.05, 23.16)];
    [bezierPath addCurveToPoint: CGPointMake(17.16, 18.3) controlPoint1: CGPointMake(17.72, 21.3) controlPoint2: CGPointMake(17.16, 19.89)];
    [bezierPath addCurveToPoint: CGPointMake(23.74, 12.09) controlPoint1: CGPointMake(17.16, 14.86) controlPoint2: CGPointMake(20.11, 12.09)];
    [bezierPath addCurveToPoint: CGPointMake(25.13, 12.26) controlPoint1: CGPointMake(24.24, 12.09) controlPoint2: CGPointMake(24.68, 12.15)];
    [bezierPath addCurveToPoint: CGPointMake(13.09, 1.13) controlPoint1: CGPointMake(24.96, 6.1) controlPoint2: CGPointMake(19.67, 1.13)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;
    
    bezierPath.usesEvenOddFillRule = YES;

    self.fillColor = [UIColor blackColor];
}

@end
