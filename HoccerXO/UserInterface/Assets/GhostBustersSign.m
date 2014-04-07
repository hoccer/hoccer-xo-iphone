//
//  GhostBustersSign.m
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "GhostBustersSign.h"

#import "HXOUI.h"

@implementation GhostBustersSign

- (void) initPath {
    CGFloat radius = 80;
    CGFloat lineWidth  = 2.5 * kHXOGridSpacing;
    CGPoint center = CGPointMake(radius, radius);
    UIBezierPath* bezierPath = self.path;
    CGPoint p = CGPointMake(2 * radius, radius);
    
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

    CGAffineTransform rotation = CGAffineTransformIdentity;
    rotation = CGAffineTransformTranslate(rotation, radius, radius);
    rotation = CGAffineTransformRotate(rotation, M_PI / 4);
    rotation = CGAffineTransformTranslate(rotation, -radius, -radius);

    [bezierPath applyTransform: rotation];

    self.fillColor = [HXOUI theme].blockSignColor;
    self.strokeColor = nil;
}

@end
