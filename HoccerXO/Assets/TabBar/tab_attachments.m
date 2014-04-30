//
//  tab_attachments.m
//  HoccerXO
//
//  Created by Peter Amende on 28.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "tab_attachments.h"

@implementation tab_attachments

- (void)initPath {
    UIBezierPath* bezierPath = self.path;

    [bezierPath moveToPoint: CGPointMake(13.51, 3.85)];
    [bezierPath addCurveToPoint: CGPointMake(13.51, 3.22) controlPoint1: CGPointMake(13.68, 3.67) controlPoint2: CGPointMake(13.68, 3.4)];
    [bezierPath addCurveToPoint: CGPointMake(12.89, 3.22) controlPoint1: CGPointMake(13.33, 3.03) controlPoint2: CGPointMake(13.07, 3.03)];
    [bezierPath addLineToPoint: CGPointMake(1.97, 14.45)];
    [bezierPath addLineToPoint: CGPointMake(2.59, 15.08)];
    [bezierPath addLineToPoint: CGPointMake(13.51, 3.85)];
    [bezierPath closePath];
    
    //// Bezier 2 Drawing
    [bezierPath moveToPoint: CGPointMake(23.68, 1.63)];
    [bezierPath addCurveToPoint: CGPointMake(18.11, 1.63) controlPoint1: CGPointMake(22.15, 0.05) controlPoint2: CGPointMake(19.65, 0.05)];
    [bezierPath addLineToPoint: CGPointMake(5.75, 14.4)];
    [bezierPath addLineToPoint: CGPointMake(5.75, 14.4)];
    [bezierPath addCurveToPoint: CGPointMake(5.75, 18.25) controlPoint1: CGPointMake(4.74, 15.44) controlPoint2: CGPointMake(4.74, 17.16)];
    [bezierPath addCurveToPoint: CGPointMake(9.47, 18.25) controlPoint1: CGPointMake(6.75, 19.29) controlPoint2: CGPointMake(8.42, 19.29)];
    [bezierPath addLineToPoint: CGPointMake(9.47, 18.25)];
    [bezierPath addLineToPoint: CGPointMake(18.46, 8.97)];
    [bezierPath addCurveToPoint: CGPointMake(18.46, 8.33) controlPoint1: CGPointMake(18.64, 8.78) controlPoint2: CGPointMake(18.64, 8.51)];
    [bezierPath addCurveToPoint: CGPointMake(17.85, 8.33) controlPoint1: CGPointMake(18.29, 8.15) controlPoint2: CGPointMake(18.03, 8.15)];
    [bezierPath addLineToPoint: CGPointMake(8.86, 17.57)];
    [bezierPath addCurveToPoint: CGPointMake(6.36, 17.57) controlPoint1: CGPointMake(8.16, 18.29) controlPoint2: CGPointMake(7.06, 18.29)];
    [bezierPath addCurveToPoint: CGPointMake(6.36, 14.99) controlPoint1: CGPointMake(5.66, 16.85) controlPoint2: CGPointMake(5.66, 15.71)];
    [bezierPath addLineToPoint: CGPointMake(18.73, 2.31)];
    [bezierPath addCurveToPoint: CGPointMake(23.07, 2.31) controlPoint1: CGPointMake(19.91, 1.09) controlPoint2: CGPointMake(21.89, 1.09)];
    [bezierPath addCurveToPoint: CGPointMake(23.07, 6.79) controlPoint1: CGPointMake(24.25, 3.53) controlPoint2: CGPointMake(24.25, 5.57)];
    [bezierPath addLineToPoint: CGPointMake(8.82, 21.51)];
    [bezierPath addCurveToPoint: CGPointMake(2.63, 21.51) controlPoint1: CGPointMake(7.11, 23.28) controlPoint2: CGPointMake(4.34, 23.28)];
    [bezierPath addCurveToPoint: CGPointMake(2.59, 15.08) controlPoint1: CGPointMake(0.88, 19.74) controlPoint2: CGPointMake(0.88, 16.85)];
    [bezierPath addLineToPoint: CGPointMake(1.97, 14.45)];
    [bezierPath addCurveToPoint: CGPointMake(1.97, 22.14) controlPoint1: CGPointMake(-0.09, 16.57) controlPoint2: CGPointMake(-0.09, 20.02)];
    [bezierPath addCurveToPoint: CGPointMake(9.43, 22.14) controlPoint1: CGPointMake(4.04, 24.27) controlPoint2: CGPointMake(7.37, 24.27)];
    [bezierPath addLineToPoint: CGPointMake(23.68, 7.43)];
    [bezierPath addCurveToPoint: CGPointMake(23.68, 1.63) controlPoint1: CGPointMake(25.22, 5.8) controlPoint2: CGPointMake(25.22, 3.26)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;
    
    self.fillColor = [UIColor blackColor];
}

@end
