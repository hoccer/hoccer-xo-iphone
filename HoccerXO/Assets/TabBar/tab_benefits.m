//
//  tab_benefits.m
//  HoccerXO
//
//  Created by Pavel Mayer on 06.04.17.
//  Copyright © 2017 Hoccer GmbH. All rights reserved.
//

#import "tab_benefits.h"


@implementation tab_benefits

- (void) initPath {
    UIBezierPath * bezierPath = self.path;

    [bezierPath moveToPoint: CGPointMake(16, 2)];
    [bezierPath addLineToPoint: CGPointMake(20.76, 12.19)];
    [bezierPath addLineToPoint: CGPointMake(31.33, 12.26)];
    [bezierPath addLineToPoint: CGPointMake(23.67, 21.78)];
    [bezierPath addLineToPoint: CGPointMake(27.76, 33)];
    [bezierPath addLineToPoint: CGPointMake(16, 26.43)];
    [bezierPath addLineToPoint: CGPointMake(3.87, 33)];
    [bezierPath addLineToPoint: CGPointMake(8.33, 21.78)];
    [bezierPath addLineToPoint: CGPointMake(0.67, 12.41)];
    [bezierPath addLineToPoint: CGPointMake(11.24, 12.19)];
    [bezierPath addLineToPoint: CGPointMake(16, 2)];
    [bezierPath closePath];

    [bezierPath moveToPoint: CGPointMake(19.75, 19.38)];
    [bezierPath addCurveToPoint: CGPointMake(19.57, 21.43) controlPoint1: CGPointMake(19.75, 20.26) controlPoint2: CGPointMake(19.69, 20.92)];
    [bezierPath addCurveToPoint: CGPointMake(18.83, 22.83) controlPoint1: CGPointMake(19.45, 21.95) controlPoint2: CGPointMake(19.14, 22.46)];
    [bezierPath addCurveToPoint: CGPointMake(16.06, 24) controlPoint1: CGPointMake(18.09, 23.63) controlPoint2: CGPointMake(17.17, 24)];
    [bezierPath addCurveToPoint: CGPointMake(13.35, 22.83) controlPoint1: CGPointMake(14.95, 24) controlPoint2: CGPointMake(14.03, 23.63)];
    [bezierPath addCurveToPoint: CGPointMake(12.49, 20.99) controlPoint1: CGPointMake(12.92, 22.31) controlPoint2: CGPointMake(12.62, 21.73)];
    [bezierPath addCurveToPoint: CGPointMake(12.37, 18.79) controlPoint1: CGPointMake(12.43, 20.55) controlPoint2: CGPointMake(12.37, 19.82)];
    [bezierPath addCurveToPoint: CGPointMake(12.49, 16.59) controlPoint1: CGPointMake(12.37, 17.77) controlPoint2: CGPointMake(12.43, 17.03)];
    [bezierPath addCurveToPoint: CGPointMake(13.35, 14.76) controlPoint1: CGPointMake(12.62, 15.86) controlPoint2: CGPointMake(12.92, 15.2)];
    [bezierPath addCurveToPoint: CGPointMake(16.06, 13.59) controlPoint1: CGPointMake(14.09, 14.03) controlPoint2: CGPointMake(15.02, 13.59)];
    [bezierPath addCurveToPoint: CGPointMake(17.78, 13.88) controlPoint1: CGPointMake(16.74, 13.59) controlPoint2: CGPointMake(17.29, 13.66)];
    [bezierPath addCurveToPoint: CGPointMake(19.14, 14.83) controlPoint1: CGPointMake(18.22, 14.1) controlPoint2: CGPointMake(18.65, 14.39)];
    [bezierPath addLineToPoint: CGPointMake(17.48, 16.52)];
    [bezierPath addCurveToPoint: CGPointMake(16.86, 16.01) controlPoint1: CGPointMake(17.23, 16.23) controlPoint2: CGPointMake(16.98, 16.08)];
    [bezierPath addCurveToPoint: CGPointMake(16.12, 15.79) controlPoint1: CGPointMake(16.68, 15.86) controlPoint2: CGPointMake(16.37, 15.79)];
    [bezierPath addCurveToPoint: CGPointMake(15.14, 16.23) controlPoint1: CGPointMake(15.69, 15.79) controlPoint2: CGPointMake(15.38, 15.93)];
    [bezierPath addCurveToPoint: CGPointMake(14.77, 18.72) controlPoint1: CGPointMake(14.89, 16.52) controlPoint2: CGPointMake(14.77, 17.4)];
    [bezierPath addCurveToPoint: CGPointMake(15.14, 21.29) controlPoint1: CGPointMake(14.77, 20.11) controlPoint2: CGPointMake(14.89, 20.92)];
    [bezierPath addCurveToPoint: CGPointMake(16.12, 21.73) controlPoint1: CGPointMake(15.32, 21.58) controlPoint2: CGPointMake(15.69, 21.73)];
    [bezierPath addCurveToPoint: CGPointMake(17.11, 21.36) controlPoint1: CGPointMake(16.55, 21.73) controlPoint2: CGPointMake(16.86, 21.58)];
    [bezierPath addCurveToPoint: CGPointMake(17.48, 20.26) controlPoint1: CGPointMake(17.35, 21.07) controlPoint2: CGPointMake(17.48, 20.7)];
    [bezierPath addLineToPoint: CGPointMake(17.48, 20.11)];
    [bezierPath addLineToPoint: CGPointMake(16.12, 20.11)];
    [bezierPath addLineToPoint: CGPointMake(16.12, 17.99)];
    [bezierPath addLineToPoint: CGPointMake(19.88, 17.99)];
    [bezierPath addLineToPoint: CGPointMake(19.88, 19.38)];
    [bezierPath addLineToPoint: CGPointMake(19.75, 19.38)];
    [bezierPath closePath];

    bezierPath.miterLimit = 4;

    bezierPath.usesEvenOddFillRule = YES;


    self.fillColor = [UIColor blackColor];
}
@end

