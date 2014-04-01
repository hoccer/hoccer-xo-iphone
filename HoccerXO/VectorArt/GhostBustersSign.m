//
//  GhostBustersSign.m
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "GhostBustersSign.h"

#import "HXOLayout.h"

@implementation GhostBustersSign

- (void) initPath {
    CGFloat radius = 80;
    CGFloat lineWidth  = 3 * kHXOGridSpacing;
    CGPoint center = CGPointMake(radius, radius);
    UIBezierPath* bezierPath = self.path;
    CGPoint p = CGPointMake(2 * radius, radius);

    CGFloat angle = 0.25 * M_PI;

    [bezierPath moveToPoint: p];
    [bezierPath addArcWithCenter: center radius: radius startAngle: 0 endAngle: 2 * M_PI clockwise: NO];
    [bezierPath addLineToPoint: p];
    [bezierPath closePath];

    CGFloat r = radius - lineWidth;
    CGFloat deltaPhi = asinf( 0.5 * lineWidth / r);
    p = CGPointMake(radius + r, radius + 0.5 * lineWidth);
    [bezierPath moveToPoint: p];
    [bezierPath addArcWithCenter: center radius: r startAngle: 0 endAngle: M_PI - deltaPhi  clockwise: YES];
    //[bezierPath addLineToPoint: p];
    [bezierPath closePath];

    p = CGPointMake(lineWidth, radius - 0.5 * lineWidth);
    [bezierPath moveToPoint: p];
    [bezierPath addArcWithCenter: center radius: r startAngle: M_PI + deltaPhi endAngle: -deltaPhi clockwise: YES];
    //[bezierPath addLineToPoint: p];
    [bezierPath closePath];

    bezierPath.usesEvenOddFillRule = YES;

    self.fillColor = [HXOTheme theme].blockSignColor;
}

@end
