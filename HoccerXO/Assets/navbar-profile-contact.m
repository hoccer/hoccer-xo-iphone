//
//  navbar-profile-contact.m
//  HoccerXO
//
//  Created by Peter Amende on 04.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "navbar-profile-contact.h"

@implementation navbar_profile_contact

- (void) initPath {
    [self.path moveToPoint: CGPointMake(12, 24)];
    [self.path addCurveToPoint: CGPointMake(0, 12) controlPoint1: CGPointMake(5.37, 24) controlPoint2: CGPointMake(0, 18.63)];
    [self.path addCurveToPoint: CGPointMake(12, -0) controlPoint1: CGPointMake(0, 5.38) controlPoint2: CGPointMake(5.37, -0)];
    [self.path addCurveToPoint: CGPointMake(24, 12) controlPoint1: CGPointMake(18.63, -0) controlPoint2: CGPointMake(24, 5.38)];
    [self.path addCurveToPoint: CGPointMake(12, 24) controlPoint1: CGPointMake(23.99, 18.63) controlPoint2: CGPointMake(18.63, 24)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(12.01, 0.49)];
    [self.path addCurveToPoint: CGPointMake(0.5, 12) controlPoint1: CGPointMake(5.65, 0.49) controlPoint2: CGPointMake(0.5, 5.65)];
    [self.path addCurveToPoint: CGPointMake(5.03, 21.13) controlPoint1: CGPointMake(0.5, 15.73) controlPoint2: CGPointMake(2.28, 19.03)];
    [self.path addCurveToPoint: CGPointMake(8.73, 15.68) controlPoint1: CGPointMake(5.16, 18.12) controlPoint2: CGPointMake(6.4, 16.24)];
    [self.path addCurveToPoint: CGPointMake(12.02, 16.5) controlPoint1: CGPointMake(9.7, 16.2) controlPoint2: CGPointMake(10.83, 16.5)];
    [self.path addCurveToPoint: CGPointMake(15.31, 15.68) controlPoint1: CGPointMake(13.21, 16.5) controlPoint2: CGPointMake(14.32, 16.21)];
    [self.path addCurveToPoint: CGPointMake(19.01, 21.13) controlPoint1: CGPointMake(17.62, 16.24) controlPoint2: CGPointMake(18.87, 18.12)];
    [self.path addCurveToPoint: CGPointMake(23.53, 12) controlPoint1: CGPointMake(21.75, 19.03) controlPoint2: CGPointMake(23.53, 15.73)];
    [self.path addCurveToPoint: CGPointMake(12.01, 0.49) controlPoint1: CGPointMake(23.51, 5.65) controlPoint2: CGPointMake(18.36, 0.49)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(12.01, 15.01)];
    [self.path addCurveToPoint: CGPointMake(6.51, 9.5) controlPoint1: CGPointMake(8.97, 15.01) controlPoint2: CGPointMake(6.51, 12.55)];
    [self.path addCurveToPoint: CGPointMake(12.01, 4) controlPoint1: CGPointMake(6.51, 6.46) controlPoint2: CGPointMake(8.96, 4)];
    [self.path addCurveToPoint: CGPointMake(17.51, 9.5) controlPoint1: CGPointMake(15.05, 4) controlPoint2: CGPointMake(17.51, 6.46)];
    [self.path addCurveToPoint: CGPointMake(12.01, 15.01) controlPoint1: CGPointMake(17.51, 12.55) controlPoint2: CGPointMake(15.04, 15.01)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.strokeColor = nil;
    self.fillColor = [[HXOUI theme] navigationBarTintColor];
}

@end
