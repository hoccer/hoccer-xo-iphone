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
    UIBezierPath* dudePath = self.path;
    [dudePath moveToPoint: CGPointMake(65.7, 61.26)];
    [dudePath addCurveToPoint: CGPointMake(65.7, 28.74) controlPoint1: CGPointMake(74.1, 52.28) controlPoint2: CGPointMake(74.1, 37.72)];
    [dudePath addCurveToPoint: CGPointMake(33.3, 28.74) controlPoint1: CGPointMake(57.31, 19.75) controlPoint2: CGPointMake(41.69, 19.75)];
    [dudePath addCurveToPoint: CGPointMake(33.3, 61.26) controlPoint1: CGPointMake(24.9, 37.72) controlPoint2: CGPointMake(24.9, 52.28)];
    [dudePath addCurveToPoint: CGPointMake(65.7, 61.26) controlPoint1: CGPointMake(41.69, 70.25) controlPoint2: CGPointMake(57.31, 70.25)];
    [dudePath closePath];
    [dudePath moveToPoint: CGPointMake(16, 99)];
    [dudePath addCurveToPoint: CGPointMake(36, 71) controlPoint1: CGPointMake(17.16, 85.66) controlPoint2: CGPointMake(28.01, 71.21)];
    [dudePath addCurveToPoint: CGPointMake(50, 74) controlPoint1: CGPointMake(37.25, 71.33) controlPoint2: CGPointMake(43.65, 74.17)];
    [dudePath addCurveToPoint: CGPointMake(63, 71) controlPoint1: CGPointMake(56.35, 73.83) controlPoint2: CGPointMake(63, 71)];
    [dudePath addCurveToPoint: CGPointMake(85, 99) controlPoint1: CGPointMake(69.95, 70.43) controlPoint2: CGPointMake(80.23, 83.45)];
    [dudePath addCurveToPoint: CGPointMake(16, 99) controlPoint1: CGPointMake(85.41, 98.96) controlPoint2: CGPointMake(16.36, 99.15)];
    [dudePath closePath];

    self.fillColor = [HXOUI theme].defaultAvatarColor;
}
@end
