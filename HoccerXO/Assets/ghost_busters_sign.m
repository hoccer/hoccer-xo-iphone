//
//  ghost_busters_sign.m
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ghost_busters_sign.h"

#import "HXOUI.h"

@implementation ghost_busters_sign

#if 0
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
#else
- (void) initPath {

    UIBezierPath* bezier2Path = self.path;
    [bezier2Path moveToPoint: CGPointMake(-0, -40)];
    [bezier2Path addCurveToPoint: CGPointMake(-23.83, -32.13) controlPoint1: CGPointMake(-8.93, -40) controlPoint2: CGPointMake(-17.17, -37.08)];
    [bezier2Path addCurveToPoint: CGPointMake(-39.69, -5) controlPoint1: CGPointMake(-32.38, -25.78) controlPoint2: CGPointMake(-38.31, -16.1)];
    [bezier2Path addLineToPoint: CGPointMake(39.69, -5)];
    [bezier2Path addCurveToPoint: CGPointMake(-0, -40) controlPoint1: CGPointMake(37.23, -24.73) controlPoint2: CGPointMake(20.4, -40)];
    [bezier2Path closePath];
    [bezier2Path moveToPoint: CGPointMake(39.69, 5)];
    [bezier2Path addLineToPoint: CGPointMake(-39.69, 5)];
    [bezier2Path addCurveToPoint: CGPointMake(-0, 40) controlPoint1: CGPointMake(-37.23, 24.73) controlPoint2: CGPointMake(-20.4, 40)];
    [bezier2Path addCurveToPoint: CGPointMake(39.69, 5) controlPoint1: CGPointMake(20.4, 40) controlPoint2: CGPointMake(37.23, 24.73)];
    [bezier2Path closePath];
    [bezier2Path moveToPoint: CGPointMake(50, -0)];
    [bezier2Path addCurveToPoint: CGPointMake(-0, 50) controlPoint1: CGPointMake(50, 27.61) controlPoint2: CGPointMake(27.61, 50)];
    [bezier2Path addCurveToPoint: CGPointMake(-50, -0) controlPoint1: CGPointMake(-27.61, 50) controlPoint2: CGPointMake(-50, 27.61)];
    [bezier2Path addCurveToPoint: CGPointMake(-31.99, -38.43) controlPoint1: CGPointMake(-50, -15.45) controlPoint2: CGPointMake(-42.99, -29.26)];
    [bezier2Path addCurveToPoint: CGPointMake(-19.44, -46.08) controlPoint1: CGPointMake(-28.23, -41.56) controlPoint2: CGPointMake(-24.01, -44.15)];
    [bezier2Path addCurveToPoint: CGPointMake(0, -50) controlPoint1: CGPointMake(-13.46, -48.6) controlPoint2: CGPointMake(-6.89, -50)];
    [bezier2Path addCurveToPoint: CGPointMake(50, -0) controlPoint1: CGPointMake(27.61, -50) controlPoint2: CGPointMake(50, -27.61)];
    [bezier2Path closePath];
    
    CGAffineTransform rotation = CGAffineTransformIdentity;
    rotation = CGAffineTransformTranslate(rotation, 50, 50);
    rotation = CGAffineTransformRotate(rotation, M_PI / 4);
    [bezier2Path applyTransform: rotation];

    self.fillColor = [HXOUI theme].blockSignColor;
    self.strokeColor = nil;
 }
#endif

@end
