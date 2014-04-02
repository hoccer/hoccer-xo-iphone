//
//  AvatarContact.m
//  HoccerXO
//
//  Created by David Siegel on 30.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AvatarContact.h"

#import "HXOUI.h"

@implementation AvatarContact

- (void) initPath {
    UIBezierPath* bezierPath = self.path;
    [bezierPath moveToPoint: CGPointMake(16, 100)];
    [bezierPath addCurveToPoint: CGPointMake(36.1, 71.33) controlPoint1: CGPointMake(16.21, 86.09) controlPoint2: CGPointMake(24.58, 74.49)];
    [bezierPath addCurveToPoint: CGPointMake(49.5, 74.7) controlPoint1: CGPointMake(40.08, 73.44) controlPoint2: CGPointMake(44.68, 74.7)];
    [bezierPath addCurveToPoint: CGPointMake(62.9, 71.33) controlPoint1: CGPointMake(54.32, 74.7) controlPoint2: CGPointMake(58.92, 73.44)];
    [bezierPath addCurveToPoint: CGPointMake(83, 100) controlPoint1: CGPointMake(74.21, 74.49) controlPoint2: CGPointMake(82.79, 86.09)];
    [bezierPath addLineToPoint: CGPointMake(16, 100)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(49.5, 68.38)];
    [bezierPath addCurveToPoint: CGPointMake(26.47, 45.19) controlPoint1: CGPointMake(36.73, 68.38) controlPoint2: CGPointMake(26.47, 58.05)];
    [bezierPath addCurveToPoint: CGPointMake(49.5, 22) controlPoint1: CGPointMake(26.47, 32.33) controlPoint2: CGPointMake(36.73, 22)];
    [bezierPath addCurveToPoint: CGPointMake(72.53, 45.19) controlPoint1: CGPointMake(62.27, 22) controlPoint2: CGPointMake(72.53, 32.33)];
    [bezierPath addCurveToPoint: CGPointMake(49.5, 68.38) controlPoint1: CGPointMake(72.53, 58.05) controlPoint2: CGPointMake(62.27, 68.38)];
    [bezierPath closePath];

    self.fillColor = [HXOUI theme].defaultAvatarColor;
}
@end
