//
//  tab_contacts.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "tab_contacts.h"

@implementation tab_contacts

- (void) initPath {
    UIBezierPath * bezierPath = self.path;

    [bezierPath moveToPoint: CGPointMake(25, 17)];
    [bezierPath addLineToPoint: CGPointMake(25, 17)];
    [bezierPath addCurveToPoint: CGPointMake(19.12, 18.5) controlPoint1: CGPointMake(25, 17.85) controlPoint2: CGPointMake(22.35, 18.5)];
    [bezierPath addCurveToPoint: CGPointMake(16.13, 18.3) controlPoint1: CGPointMake(18.04, 18.5) controlPoint2: CGPointMake(17.01, 18.4)];
    [bezierPath addCurveToPoint: CGPointMake(16.18, 19) controlPoint1: CGPointMake(16.18, 18.5) controlPoint2: CGPointMake(16.18, 18.75)];
    [bezierPath addLineToPoint: CGPointMake(16.18, 19)];
    [bezierPath addLineToPoint: CGPointMake(16.18, 19)];
    [bezierPath addCurveToPoint: CGPointMake(8.09, 21) controlPoint1: CGPointMake(16.18, 20.1) controlPoint2: CGPointMake(12.55, 21)];
    [bezierPath addCurveToPoint: CGPointMake(0, 19) controlPoint1: CGPointMake(3.63, 21) controlPoint2: CGPointMake(0, 20.1)];
    [bezierPath addLineToPoint: CGPointMake(0, 19)];
    [bezierPath addLineToPoint: CGPointMake(0, 19)];
    [bezierPath addCurveToPoint: CGPointMake(3.92, 12.65) controlPoint1: CGPointMake(0.05, 15.8) controlPoint2: CGPointMake(1.62, 13.6)];
    [bezierPath addCurveToPoint: CGPointMake(8.33, 14.05) controlPoint1: CGPointMake(5.2, 13.5) controlPoint2: CGPointMake(6.72, 14.05)];
    [bezierPath addCurveToPoint: CGPointMake(12.55, 12.8) controlPoint1: CGPointMake(9.9, 14.05) controlPoint2: CGPointMake(11.32, 13.6)];
    [bezierPath addCurveToPoint: CGPointMake(14.07, 13.85) controlPoint1: CGPointMake(13.14, 13.05) controlPoint2: CGPointMake(13.63, 13.4)];
    [bezierPath addCurveToPoint: CGPointMake(15.93, 12.1) controlPoint1: CGPointMake(14.56, 13.1) controlPoint2: CGPointMake(15.2, 12.5)];
    [bezierPath addCurveToPoint: CGPointMake(19.12, 13.05) controlPoint1: CGPointMake(16.86, 12.7) controlPoint2: CGPointMake(17.94, 13.05)];
    [bezierPath addCurveToPoint: CGPointMake(22.25, 12.1) controlPoint1: CGPointMake(20.29, 13.05) controlPoint2: CGPointMake(21.37, 12.7)];
    [bezierPath addCurveToPoint: CGPointMake(25, 17) controlPoint1: CGPointMake(23.87, 12.85) controlPoint2: CGPointMake(24.95, 14.55)];
    [bezierPath addLineToPoint: CGPointMake(25, 17)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(12.5, 13.9)];
    [bezierPath addCurveToPoint: CGPointMake(8.33, 15) controlPoint1: CGPointMake(11.27, 14.6) controlPoint2: CGPointMake(9.85, 15)];
    [bezierPath addCurveToPoint: CGPointMake(3.92, 13.8) controlPoint1: CGPointMake(6.72, 15) controlPoint2: CGPointMake(5.2, 14.55)];
    [bezierPath addCurveToPoint: CGPointMake(0.98, 19) controlPoint1: CGPointMake(2.16, 14.7) controlPoint2: CGPointMake(1.03, 16.5)];
    [bezierPath addLineToPoint: CGPointMake(0.98, 19)];
    [bezierPath addLineToPoint: CGPointMake(0.98, 19)];
    [bezierPath addCurveToPoint: CGPointMake(8.09, 20) controlPoint1: CGPointMake(0.98, 19.55) controlPoint2: CGPointMake(4.17, 20)];
    [bezierPath addCurveToPoint: CGPointMake(15.2, 19) controlPoint1: CGPointMake(12.01, 20) controlPoint2: CGPointMake(15.2, 19.55)];
    [bezierPath addLineToPoint: CGPointMake(15.2, 19)];
    [bezierPath addLineToPoint: CGPointMake(15.2, 19)];
    [bezierPath addCurveToPoint: CGPointMake(12.5, 13.9) controlPoint1: CGPointMake(15.15, 16.6) controlPoint2: CGPointMake(14.12, 14.9)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(19.12, 11.5)];
    [bezierPath addCurveToPoint: CGPointMake(15.2, 7.5) controlPoint1: CGPointMake(16.96, 11.5) controlPoint2: CGPointMake(15.2, 9.7)];
    [bezierPath addCurveToPoint: CGPointMake(19.12, 3.5) controlPoint1: CGPointMake(15.2, 5.3) controlPoint2: CGPointMake(16.96, 3.5)];
    [bezierPath addCurveToPoint: CGPointMake(23.04, 7.5) controlPoint1: CGPointMake(21.27, 3.5) controlPoint2: CGPointMake(23.04, 5.3)];
    [bezierPath addCurveToPoint: CGPointMake(19.12, 11.5) controlPoint1: CGPointMake(23.04, 9.7) controlPoint2: CGPointMake(21.27, 11.5)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(8.33, 12)];
    [bezierPath addCurveToPoint: CGPointMake(2.45, 6) controlPoint1: CGPointMake(5.1, 12) controlPoint2: CGPointMake(2.45, 9.3)];
    [bezierPath addCurveToPoint: CGPointMake(8.33, 0) controlPoint1: CGPointMake(2.45, 2.7) controlPoint2: CGPointMake(5.1, 0)];
    [bezierPath addCurveToPoint: CGPointMake(14.22, 6) controlPoint1: CGPointMake(11.57, 0) controlPoint2: CGPointMake(14.22, 2.7)];
    [bezierPath addCurveToPoint: CGPointMake(8.33, 12) controlPoint1: CGPointMake(14.22, 9.3) controlPoint2: CGPointMake(11.57, 12)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(8.33, 1)];
    [bezierPath addCurveToPoint: CGPointMake(3.43, 6) controlPoint1: CGPointMake(5.64, 1) controlPoint2: CGPointMake(3.43, 3.25)];
    [bezierPath addCurveToPoint: CGPointMake(8.33, 11) controlPoint1: CGPointMake(3.43, 8.75) controlPoint2: CGPointMake(5.64, 11)];
    [bezierPath addCurveToPoint: CGPointMake(13.24, 6) controlPoint1: CGPointMake(11.03, 11) controlPoint2: CGPointMake(13.24, 8.75)];
    [bezierPath addCurveToPoint: CGPointMake(8.33, 1) controlPoint1: CGPointMake(13.24, 3.25) controlPoint2: CGPointMake(11.03, 1)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;
    
    bezierPath.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor blackColor];
}

@end
