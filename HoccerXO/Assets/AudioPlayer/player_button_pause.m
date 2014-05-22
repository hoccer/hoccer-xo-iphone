//
//  player_button_pause.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_button_pause.h"

@implementation player_button_pause

- (void)initPath {

    [self.path moveToPoint: CGPointMake(26.19, 18.88)];
    [self.path addLineToPoint: CGPointMake(23.23, 18.88)];
    [self.path addCurveToPoint: CGPointMake(21.81, 20.3) controlPoint1: CGPointMake(22.45, 18.88) controlPoint2: CGPointMake(21.81, 19.52)];
    [self.path addLineToPoint: CGPointMake(21.81, 43.57)];
    [self.path addCurveToPoint: CGPointMake(23.23, 44.99) controlPoint1: CGPointMake(21.81, 44.35) controlPoint2: CGPointMake(22.45, 44.99)];
    [self.path addLineToPoint: CGPointMake(26.19, 44.99)];
    [self.path addCurveToPoint: CGPointMake(27.61, 43.57) controlPoint1: CGPointMake(26.97, 44.99) controlPoint2: CGPointMake(27.61, 44.35)];
    [self.path addLineToPoint: CGPointMake(27.61, 20.3)];
    [self.path addCurveToPoint: CGPointMake(26.19, 18.88) controlPoint1: CGPointMake(27.61, 19.52) controlPoint2: CGPointMake(26.97, 18.88)];
    [self.path closePath];
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
    [self.path moveToPoint: CGPointMake(40.65, 18.88)];
    [self.path addLineToPoint: CGPointMake(37.68, 18.88)];
    [self.path addCurveToPoint: CGPointMake(36.26, 20.3) controlPoint1: CGPointMake(36.9, 18.88) controlPoint2: CGPointMake(36.26, 19.52)];
    [self.path addLineToPoint: CGPointMake(36.26, 43.57)];
    [self.path addCurveToPoint: CGPointMake(37.68, 44.99) controlPoint1: CGPointMake(36.26, 44.35) controlPoint2: CGPointMake(36.9, 44.99)];
    [self.path addLineToPoint: CGPointMake(40.65, 44.99)];
    [self.path addCurveToPoint: CGPointMake(42.06, 43.57) controlPoint1: CGPointMake(41.42, 44.99) controlPoint2: CGPointMake(42.06, 44.35)];
    [self.path addLineToPoint: CGPointMake(42.06, 20.3)];
    [self.path addCurveToPoint: CGPointMake(40.65, 18.88) controlPoint1: CGPointMake(42.06, 19.52) controlPoint2: CGPointMake(41.42, 18.88)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];
    
    

}

@end
