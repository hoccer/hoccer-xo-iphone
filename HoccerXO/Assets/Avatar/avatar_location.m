//
//  avatar_location.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "avatar_location.h"

@implementation avatar_location

- (void) initPath {
    UIBezierPath* bezierPath = self.path;
    [bezierPath moveToPoint: CGPointMake(71.86, 76.96)];
    [bezierPath addLineToPoint: CGPointMake(71.86, 76.96)];
    [bezierPath addLineToPoint: CGPointMake(49.01, 99.5)];
    [bezierPath addLineToPoint: CGPointMake(26.2, 76.96)];
    [bezierPath addCurveToPoint: CGPointMake(26.2, 31.91) controlPoint1: CGPointMake(13.57, 64.49) controlPoint2: CGPointMake(13.57, 44.33)];
    [bezierPath addCurveToPoint: CGPointMake(71.86, 31.91) controlPoint1: CGPointMake(38.84, 19.5) controlPoint2: CGPointMake(59.27, 19.5)];
    [bezierPath addCurveToPoint: CGPointMake(71.86, 76.96) controlPoint1: CGPointMake(84.45, 44.33) controlPoint2: CGPointMake(84.45, 64.49)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(56.53, 46.99)];
    [bezierPath addCurveToPoint: CGPointMake(41.48, 46.99) controlPoint1: CGPointMake(52.38, 42.89) controlPoint2: CGPointMake(45.63, 42.89)];
    [bezierPath addCurveToPoint: CGPointMake(41.48, 61.84) controlPoint1: CGPointMake(37.33, 51.08) controlPoint2: CGPointMake(37.33, 57.74)];
    [bezierPath addCurveToPoint: CGPointMake(56.53, 61.84) controlPoint1: CGPointMake(45.63, 65.93) controlPoint2: CGPointMake(52.38, 65.93)];
    [bezierPath addCurveToPoint: CGPointMake(56.53, 46.99) controlPoint1: CGPointMake(60.73, 57.74) controlPoint2: CGPointMake(60.73, 51.08)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;

    self.fillColor = [HXOUI theme].defaultAvatarColor;
}

@end
