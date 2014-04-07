//
//  IconProfile.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "IconProfile.h"

@implementation IconProfile

- (void) initPath {
    UIBezierPath * bezierPath = self.path;

    [bezierPath moveToPoint: CGPointMake(12.2, 24.4)];
    [bezierPath addCurveToPoint: CGPointMake(0, 12.2) controlPoint1: CGPointMake(5.47, 24.4) controlPoint2: CGPointMake(0, 18.93)];
    [bezierPath addCurveToPoint: CGPointMake(12.2, 0) controlPoint1: CGPointMake(0, 5.47) controlPoint2: CGPointMake(5.47, 0)];
    [bezierPath addCurveToPoint: CGPointMake(24.4, 12.2) controlPoint1: CGPointMake(18.93, 0) controlPoint2: CGPointMake(24.4, 5.47)];
    [bezierPath addCurveToPoint: CGPointMake(12.2, 24.4) controlPoint1: CGPointMake(24.4, 18.93) controlPoint2: CGPointMake(18.93, 24.4)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(12.25, 1.11)];
    [bezierPath addCurveToPoint: CGPointMake(1.11, 12.25) controlPoint1: CGPointMake(6.1, 1.11) controlPoint2: CGPointMake(1.11, 6.1)];
    [bezierPath addCurveToPoint: CGPointMake(5.03, 20.72) controlPoint1: CGPointMake(1.11, 15.64) controlPoint2: CGPointMake(2.61, 18.69)];
    [bezierPath addCurveToPoint: CGPointMake(9, 16.27) controlPoint1: CGPointMake(5.28, 18.06) controlPoint2: CGPointMake(6.78, 16.65)];
    [bezierPath addCurveToPoint: CGPointMake(12.25, 17.09) controlPoint1: CGPointMake(9.97, 16.8) controlPoint2: CGPointMake(11.09, 17.09)];
    [bezierPath addCurveToPoint: CGPointMake(15.49, 16.27) controlPoint1: CGPointMake(13.41, 17.09) controlPoint2: CGPointMake(14.52, 16.8)];
    [bezierPath addCurveToPoint: CGPointMake(19.46, 20.72) controlPoint1: CGPointMake(17.72, 16.7) controlPoint2: CGPointMake(19.22, 18.11)];
    [bezierPath addCurveToPoint: CGPointMake(23.38, 12.25) controlPoint1: CGPointMake(21.83, 18.69) controlPoint2: CGPointMake(23.38, 15.64)];
    [bezierPath addCurveToPoint: CGPointMake(12.25, 1.11) controlPoint1: CGPointMake(23.38, 6.1) controlPoint2: CGPointMake(18.4, 1.11)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(12.25, 15.69)];
    [bezierPath addCurveToPoint: CGPointMake(6.92, 10.36) controlPoint1: CGPointMake(9.3, 15.69) controlPoint2: CGPointMake(6.92, 13.31)];
    [bezierPath addCurveToPoint: CGPointMake(12.25, 5.03) controlPoint1: CGPointMake(6.92, 7.41) controlPoint2: CGPointMake(9.3, 5.03)];
    [bezierPath addCurveToPoint: CGPointMake(17.57, 10.36) controlPoint1: CGPointMake(15.2, 5.03) controlPoint2: CGPointMake(17.57, 7.41)];
    [bezierPath addCurveToPoint: CGPointMake(12.25, 15.69) controlPoint1: CGPointMake(17.57, 13.31) controlPoint2: CGPointMake(15.15, 15.69)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;
    
    bezierPath.usesEvenOddFillRule = YES;
    

    self.fillColor = [UIColor blackColor];
}

@end
