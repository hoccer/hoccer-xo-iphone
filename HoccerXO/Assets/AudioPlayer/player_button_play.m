//
//  player_button_play.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_play.h"

@implementation player_button_play

- (void)initPath {

    [self.path moveToPoint: CGPointMake(32, 0)];
    [self.path addCurveToPoint: CGPointMake(0, 31.94) controlPoint1: CGPointMake(14.32, 0) controlPoint2: CGPointMake(0, 14.35)];
    [self.path addCurveToPoint: CGPointMake(32, 64) controlPoint1: CGPointMake(0, 49.65) controlPoint2: CGPointMake(14.32, 64)];
    [self.path addCurveToPoint: CGPointMake(64, 31.94) controlPoint1: CGPointMake(49.68, 64) controlPoint2: CGPointMake(64, 49.65)];
    [self.path addCurveToPoint: CGPointMake(32, 0) controlPoint1: CGPointMake(63.87, 14.35) controlPoint2: CGPointMake(49.55, 0)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(32, 62.58)];
    [self.path addCurveToPoint: CGPointMake(1.55, 32.06) controlPoint1: CGPointMake(15.23, 62.58) controlPoint2: CGPointMake(1.55, 48.87)];
    [self.path addCurveToPoint: CGPointMake(32, 1.55) controlPoint1: CGPointMake(1.55, 15.26) controlPoint2: CGPointMake(15.23, 1.55)];
    [self.path addCurveToPoint: CGPointMake(62.45, 32.06) controlPoint1: CGPointMake(48.77, 1.55) controlPoint2: CGPointMake(62.45, 15.26)];
    [self.path addCurveToPoint: CGPointMake(32, 62.58) controlPoint1: CGPointMake(62.45, 48.87) controlPoint2: CGPointMake(48.77, 62.58)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(45.68, 30.77)];
    [self.path addCurveToPoint: CGPointMake(26.71, 19.14) controlPoint1: CGPointMake(44.26, 29.87) controlPoint2: CGPointMake(27.61, 19.65)];
    [self.path addCurveToPoint: CGPointMake(24.65, 20.43) controlPoint1: CGPointMake(25.68, 18.49) controlPoint2: CGPointMake(24.65, 19.26)];
    [self.path addCurveToPoint: CGPointMake(24.65, 43.7) controlPoint1: CGPointMake(24.65, 21.2) controlPoint2: CGPointMake(24.65, 42.54)];
    [self.path addCurveToPoint: CGPointMake(26.71, 44.99) controlPoint1: CGPointMake(24.65, 44.86) controlPoint2: CGPointMake(25.81, 45.51)];
    [self.path addCurveToPoint: CGPointMake(45.68, 33.36) controlPoint1: CGPointMake(27.87, 44.22) controlPoint2: CGPointMake(44.65, 34)];
    [self.path addCurveToPoint: CGPointMake(45.68, 30.77) controlPoint1: CGPointMake(46.71, 32.71) controlPoint2: CGPointMake(46.71, 31.29)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    

    
        self.fillColor = [UIColor whiteColor];
    

}
@end
