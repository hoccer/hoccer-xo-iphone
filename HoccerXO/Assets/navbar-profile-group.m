//
//  navbar-profile-group.m
//  HoccerXO
//
//  Created by Peter Amende on 04.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "navbar-profile-group.h"

@implementation navbar_profile_group

- (void) initPath {
    [self.path moveToPoint: CGPointMake(12, 24)];
    [self.path addCurveToPoint: CGPointMake(0, 12) controlPoint1: CGPointMake(5.33, 24) controlPoint2: CGPointMake(0, 18.67)];
    [self.path addCurveToPoint: CGPointMake(12, 0) controlPoint1: CGPointMake(0, 5.33) controlPoint2: CGPointMake(5.33, 0)];
    [self.path addCurveToPoint: CGPointMake(24, 12) controlPoint1: CGPointMake(18.67, 0) controlPoint2: CGPointMake(24, 5.33)];
    [self.path addCurveToPoint: CGPointMake(12, 24) controlPoint1: CGPointMake(24, 18.67) controlPoint2: CGPointMake(18.67, 24)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(11.02, 23.47)];
    [self.path addCurveToPoint: CGPointMake(16, 22.49) controlPoint1: CGPointMake(13.96, 23.38) controlPoint2: CGPointMake(16, 22.93)];
    [self.path addLineToPoint: CGPointMake(16, 22.49)];
    [self.path addLineToPoint: CGPointMake(16, 22.49)];
    [self.path addCurveToPoint: CGPointMake(13.24, 17.42) controlPoint1: CGPointMake(16, 20.09) controlPoint2: CGPointMake(14.93, 18.4)];
    [self.path addCurveToPoint: CGPointMake(8.98, 18.49) controlPoint1: CGPointMake(12, 18.13) controlPoint2: CGPointMake(10.49, 18.49)];
    [self.path addCurveToPoint: CGPointMake(4.44, 17.24) controlPoint1: CGPointMake(7.29, 18.49) controlPoint2: CGPointMake(5.78, 18.04)];
    [self.path addCurveToPoint: CGPointMake(2.67, 18.76) controlPoint1: CGPointMake(3.73, 17.6) controlPoint2: CGPointMake(3.2, 18.13)];
    [self.path addCurveToPoint: CGPointMake(11.02, 23.47) controlPoint1: CGPointMake(4.62, 21.42) controlPoint2: CGPointMake(7.56, 23.11)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(12, 0.53)];
    [self.path addCurveToPoint: CGPointMake(0.53, 12) controlPoint1: CGPointMake(5.69, 0.53) controlPoint2: CGPointMake(0.53, 5.69)];
    [self.path addCurveToPoint: CGPointMake(2.13, 17.87) controlPoint1: CGPointMake(0.53, 14.13) controlPoint2: CGPointMake(1.16, 16.18)];
    [self.path addCurveToPoint: CGPointMake(4.53, 16.09) controlPoint1: CGPointMake(2.76, 17.07) controlPoint2: CGPointMake(3.56, 16.53)];
    [self.path addCurveToPoint: CGPointMake(8.98, 17.42) controlPoint1: CGPointMake(5.78, 16.98) controlPoint2: CGPointMake(7.38, 17.42)];
    [self.path addCurveToPoint: CGPointMake(13.24, 16.18) controlPoint1: CGPointMake(10.58, 17.42) controlPoint2: CGPointMake(12, 16.98)];
    [self.path addCurveToPoint: CGPointMake(14.49, 16.98) controlPoint1: CGPointMake(13.69, 16.36) controlPoint2: CGPointMake(14.13, 16.62)];
    [self.path addCurveToPoint: CGPointMake(14.93, 16.8) controlPoint1: CGPointMake(14.67, 16.89) controlPoint2: CGPointMake(14.76, 16.8)];
    [self.path addCurveToPoint: CGPointMake(18.22, 17.78) controlPoint1: CGPointMake(15.82, 17.42) controlPoint2: CGPointMake(16.98, 17.78)];
    [self.path addCurveToPoint: CGPointMake(21.33, 16.89) controlPoint1: CGPointMake(19.38, 17.78) controlPoint2: CGPointMake(20.44, 17.42)];
    [self.path addCurveToPoint: CGPointMake(22.13, 17.42) controlPoint1: CGPointMake(21.6, 17.07) controlPoint2: CGPointMake(21.87, 17.24)];
    [self.path addCurveToPoint: CGPointMake(23.47, 12) controlPoint1: CGPointMake(23.02, 15.82) controlPoint2: CGPointMake(23.47, 13.96)];
    [self.path addCurveToPoint: CGPointMake(12, 0.53) controlPoint1: CGPointMake(23.47, 5.69) controlPoint2: CGPointMake(18.31, 0.53)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(18.22, 16.36)];
    [self.path addCurveToPoint: CGPointMake(13.96, 12.89) controlPoint1: CGPointMake(16.18, 16.36) controlPoint2: CGPointMake(14.4, 14.84)];
    [self.path addCurveToPoint: CGPointMake(9.07, 15.47) controlPoint1: CGPointMake(12.89, 14.49) controlPoint2: CGPointMake(11.11, 15.47)];
    [self.path addCurveToPoint: CGPointMake(3.02, 9.42) controlPoint1: CGPointMake(5.78, 15.47) controlPoint2: CGPointMake(3.02, 12.8)];
    [self.path addCurveToPoint: CGPointMake(9.07, 3.47) controlPoint1: CGPointMake(3.02, 6.13) controlPoint2: CGPointMake(5.69, 3.47)];
    [self.path addCurveToPoint: CGPointMake(15.02, 8.89) controlPoint1: CGPointMake(12.18, 3.47) controlPoint2: CGPointMake(14.76, 5.87)];
    [self.path addCurveToPoint: CGPointMake(18.22, 7.47) controlPoint1: CGPointMake(15.82, 8) controlPoint2: CGPointMake(16.98, 7.47)];
    [self.path addCurveToPoint: CGPointMake(22.58, 11.91) controlPoint1: CGPointMake(20.62, 7.47) controlPoint2: CGPointMake(22.58, 9.42)];
    [self.path addCurveToPoint: CGPointMake(18.22, 16.36) controlPoint1: CGPointMake(22.58, 14.4) controlPoint2: CGPointMake(20.62, 16.36)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(8.98, 4.53)];
    [self.path addCurveToPoint: CGPointMake(4, 9.51) controlPoint1: CGPointMake(6.22, 4.53) controlPoint2: CGPointMake(4, 6.76)];
    [self.path addCurveToPoint: CGPointMake(8.98, 14.49) controlPoint1: CGPointMake(4, 12.27) controlPoint2: CGPointMake(6.22, 14.49)];
    [self.path addCurveToPoint: CGPointMake(13.96, 9.51) controlPoint1: CGPointMake(11.73, 14.49) controlPoint2: CGPointMake(13.96, 12.27)];
    [self.path addCurveToPoint: CGPointMake(8.98, 4.53) controlPoint1: CGPointMake(14.04, 6.76) controlPoint2: CGPointMake(11.73, 4.53)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.strokeColor = nil;
    self.fillColor = [[HXOUI theme] navigationBarTintColor];
}


@end
