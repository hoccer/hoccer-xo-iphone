//
//  PaperClip.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "PaperClip.h"

@implementation PaperClip

static const CGFloat kStartX = 18.5;
static const CGFloat kBigRadius = 6;
static const CGFloat kSecondBendX = 22.5;
static const CGFloat kSmallRadius = 3;
static const CGFloat kSecondBendRadius = (kBigRadius + kSmallRadius) / 2;
static const CGFloat kInnerBendX = 12.5;
static const CGFloat kInnerEndX = kStartX;


- (void) initPath {
    [self.path moveToPoint: CGPointMake(kStartX, .5)];
    [self.path addLineToPoint: CGPointMake(kBigRadius, .5)];
    [self.path addArcWithCenter: CGPointMake(kBigRadius +.5, kBigRadius +.5) radius: kBigRadius startAngle: 1.5 * M_PI endAngle:  0.5 * M_PI clockwise: NO];
    [self.path addLineToPoint: CGPointMake(kSecondBendX, 2 * kBigRadius)];
    [self.path addArcWithCenter: CGPointMake(kSecondBendX, 2 * kBigRadius - kSecondBendRadius) radius: kSecondBendRadius startAngle: 0.5 * M_PI endAngle:  1.5 * M_PI clockwise: NO];
    [self.path addLineToPoint: CGPointMake(kInnerBendX, 2 * (kBigRadius - kSecondBendRadius))];
    [self.path addArcWithCenter: CGPointMake(kInnerBendX,  kBigRadius + .25) radius: kSmallRadius + .25 startAngle: 1.5 * M_PI endAngle:  0.5 * M_PI clockwise: NO];
    [self.path addLineToPoint: CGPointMake(kInnerEndX, kBigRadius + kSmallRadius + .5)];

    self.strokeColor = [UIColor blackColor];
    self.path.lineWidth = 1.0;
}
@end
