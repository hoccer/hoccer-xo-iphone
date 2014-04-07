//
//  AvatarGroup.m
//  HoccerXO
//
//  Created by David Siegel on 02.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AvatarGroup.h"

@implementation AvatarGroup

- (void) initPath {
    UIBezierPath * bezierPath = self.path;
    [bezierPath moveToPoint: CGPointMake(73.5, 67.69)];
    [bezierPath addLineToPoint: CGPointMake(73.5, 67.69)];
    [bezierPath addCurveToPoint: CGPointMake(65.48, 62.78) controlPoint1: CGPointMake(71.05, 65.68) controlPoint2: CGPointMake(68.38, 63.9)];
    [bezierPath addCurveToPoint: CGPointMake(74.61, 43.17) controlPoint1: CGPointMake(71.05, 58.1) controlPoint2: CGPointMake(74.61, 50.97)];
    [bezierPath addCurveToPoint: CGPointMake(71.05, 30.02) controlPoint1: CGPointMake(74.61, 38.27) controlPoint2: CGPointMake(73.28, 33.81)];
    [bezierPath addCurveToPoint: CGPointMake(73.72, 29.8) controlPoint1: CGPointMake(71.94, 29.8) controlPoint2: CGPointMake(72.83, 29.8)];
    [bezierPath addCurveToPoint: CGPointMake(92.65, 48.74) controlPoint1: CGPointMake(84.19, 29.8) controlPoint2: CGPointMake(92.65, 38.27)];
    [bezierPath addCurveToPoint: CGPointMake(73.5, 67.69) controlPoint1: CGPointMake(92.43, 59.22) controlPoint2: CGPointMake(83.97, 67.69)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(49, 64.34)];
    [bezierPath addCurveToPoint: CGPointMake(27.84, 43.17) controlPoint1: CGPointMake(37.42, 64.34) controlPoint2: CGPointMake(27.84, 54.76)];
    [bezierPath addCurveToPoint: CGPointMake(49, 22) controlPoint1: CGPointMake(27.84, 31.58) controlPoint2: CGPointMake(37.42, 22)];
    [bezierPath addCurveToPoint: CGPointMake(70.16, 43.17) controlPoint1: CGPointMake(60.58, 22) controlPoint2: CGPointMake(70.16, 31.58)];
    [bezierPath addCurveToPoint: CGPointMake(49, 64.34) controlPoint1: CGPointMake(70.16, 54.76) controlPoint2: CGPointMake(60.58, 64.34)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(32.52, 62.78)];
    [bezierPath addCurveToPoint: CGPointMake(24.72, 67.69) controlPoint1: CGPointMake(29.62, 63.9) controlPoint2: CGPointMake(26.95, 65.46)];
    [bezierPath addLineToPoint: CGPointMake(24.5, 67.69)];
    [bezierPath addCurveToPoint: CGPointMake(5.57, 48.74) controlPoint1: CGPointMake(14.03, 67.69) controlPoint2: CGPointMake(5.57, 59.22)];
    [bezierPath addCurveToPoint: CGPointMake(24.5, 29.8) controlPoint1: CGPointMake(5.57, 38.27) controlPoint2: CGPointMake(14.03, 29.8)];
    [bezierPath addCurveToPoint: CGPointMake(27.17, 30.02) controlPoint1: CGPointMake(25.39, 29.8) controlPoint2: CGPointMake(26.28, 29.8)];
    [bezierPath addCurveToPoint: CGPointMake(23.61, 43.17) controlPoint1: CGPointMake(24.95, 33.81) controlPoint2: CGPointMake(23.61, 38.27)];
    [bezierPath addCurveToPoint: CGPointMake(32.52, 62.78) controlPoint1: CGPointMake(23.39, 50.97) controlPoint2: CGPointMake(26.95, 58.1)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(12.7, 70.14)];
    [bezierPath addCurveToPoint: CGPointMake(20.27, 72.81) controlPoint1: CGPointMake(14.92, 71.47) controlPoint2: CGPointMake(17.6, 72.37)];
    [bezierPath addCurveToPoint: CGPointMake(14.48, 91.09) controlPoint1: CGPointMake(16.7, 77.94) controlPoint2: CGPointMake(14.7, 84.18)];
    [bezierPath addLineToPoint: CGPointMake(14.48, 100)];
    [bezierPath addLineToPoint: CGPointMake(0, 100)];
    [bezierPath addLineToPoint: CGPointMake(0, 91.09)];
    [bezierPath addCurveToPoint: CGPointMake(12.7, 70.14) controlPoint1: CGPointMake(0.22, 81.73) controlPoint2: CGPointMake(5.35, 73.7)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(36.53, 65.46)];
    [bezierPath addCurveToPoint: CGPointMake(49, 68.8) controlPoint1: CGPointMake(40.09, 67.69) controlPoint2: CGPointMake(44.32, 68.8)];
    [bezierPath addCurveToPoint: CGPointMake(61.47, 65.46) controlPoint1: CGPointMake(53.68, 68.8) controlPoint2: CGPointMake(57.91, 67.69)];
    [bezierPath addCurveToPoint: CGPointMake(79.07, 91.09) controlPoint1: CGPointMake(71.5, 68.58) controlPoint2: CGPointMake(78.85, 78.83)];
    [bezierPath addLineToPoint: CGPointMake(79.07, 100)];
    [bezierPath addLineToPoint: CGPointMake(18.93, 100)];
    [bezierPath addLineToPoint: CGPointMake(18.93, 91.09)];
    [bezierPath addCurveToPoint: CGPointMake(36.53, 65.46) controlPoint1: CGPointMake(18.93, 78.83) controlPoint2: CGPointMake(26.5, 68.58)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(83.52, 91.09)];
    [bezierPath addCurveToPoint: CGPointMake(77.73, 72.81) controlPoint1: CGPointMake(83.52, 84.18) controlPoint2: CGPointMake(81.3, 77.94)];
    [bezierPath addCurveToPoint: CGPointMake(85.3, 70.14) controlPoint1: CGPointMake(80.4, 72.37) controlPoint2: CGPointMake(83.08, 71.47)];
    [bezierPath addCurveToPoint: CGPointMake(98, 91.09) controlPoint1: CGPointMake(92.65, 73.7) controlPoint2: CGPointMake(97.78, 81.73)];
    [bezierPath addLineToPoint: CGPointMake(98, 100)];
    [bezierPath addLineToPoint: CGPointMake(83.52, 100)];
    [bezierPath addLineToPoint: CGPointMake(83.52, 91.09)];
    [bezierPath closePath];

    self.fillColor = [HXOUI theme].defaultAvatarColor;
}

@end
