//
//  player_icon_volume_down.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_icon_volume_down.h"

@implementation player_icon_volume_down

- (void)initPath {

    [self.path moveToPoint: CGPointMake(5.57, 28.54)];
    [self.path addLineToPoint: CGPointMake(3, 26.08)];
    [self.path addLineToPoint: CGPointMake(23.43, 6.54)];
    [self.path addLineToPoint: CGPointMake(26, 9)];
    [self.path addLineToPoint: CGPointMake(5.57, 28.54)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(4.45, 22.08)];
    [self.path addLineToPoint: CGPointMake(4.45, 10.85)];
    [self.path addCurveToPoint: CGPointMake(6.22, 9.15) controlPoint1: CGPointMake(4.45, 9.92) controlPoint2: CGPointMake(5.25, 9.15)];
    [self.path addLineToPoint: CGPointMake(13.13, 9.15)];
    [self.path addLineToPoint: CGPointMake(20.69, 3)];
    [self.path addLineToPoint: CGPointMake(20.69, 6.69)];
    [self.path addLineToPoint: CGPointMake(4.45, 22.23)];
    [self.path addLineToPoint: CGPointMake(4.45, 22.08)];
    [self.path closePath];
    [self.path moveToPoint: CGPointMake(20.69, 29)];
    [self.path addLineToPoint: CGPointMake(14.1, 23.77)];
    [self.path addLineToPoint: CGPointMake(13.13, 23.77)];
    [self.path addLineToPoint: CGPointMake(20.69, 16.54)];
    [self.path addLineToPoint: CGPointMake(20.69, 29)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.path.usesEvenOddFillRule = YES;
    
    self.fillColor = [UIColor whiteColor];
    
}

@end
