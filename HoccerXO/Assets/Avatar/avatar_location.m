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
    [bezierPath moveToPoint: CGPointMake(64.05, 60.23)];
    [bezierPath addLineToPoint: CGPointMake(64.05, 60.23)];
    [bezierPath addLineToPoint: CGPointMake(46.51, 77.5)];
    [bezierPath addLineToPoint: CGPointMake(29, 60.23)];
    [bezierPath addCurveToPoint: CGPointMake(29, 25.73) controlPoint1: CGPointMake(19.3, 50.69) controlPoint2: CGPointMake(19.3, 35.25)];
    [bezierPath addCurveToPoint: CGPointMake(64.05, 25.73) controlPoint1: CGPointMake(38.7, 16.22) controlPoint2: CGPointMake(54.39, 16.22)];
    [bezierPath addCurveToPoint: CGPointMake(64.05, 60.23) controlPoint1: CGPointMake(73.72, 35.25) controlPoint2: CGPointMake(73.72, 50.69)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(52.29, 37.28)];
    [bezierPath addCurveToPoint: CGPointMake(40.73, 37.28) controlPoint1: CGPointMake(49.1, 34.14) controlPoint2: CGPointMake(43.92, 34.14)];
    [bezierPath addCurveToPoint: CGPointMake(40.73, 48.65) controlPoint1: CGPointMake(37.54, 40.42) controlPoint2: CGPointMake(37.54, 45.52)];
    [bezierPath addCurveToPoint: CGPointMake(52.29, 48.65) controlPoint1: CGPointMake(43.92, 51.79) controlPoint2: CGPointMake(49.1, 51.79)];
    [bezierPath addCurveToPoint: CGPointMake(52.29, 37.28) controlPoint1: CGPointMake(55.51, 45.52) controlPoint2: CGPointMake(55.51, 40.42)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;

    self.fillColor = [HXOUI theme].defaultAvatarColor;
}

- (UIBezierPath*) pathScaledToSize:(CGSize)size {
    CGFloat s = 0.84;
    return [super  pathScaledToSize: CGSizeMake(size.width, s * size.height)];
}

@end
