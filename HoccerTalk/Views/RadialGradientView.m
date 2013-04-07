//
//  RadialGradientView.m
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "RadialGradientView.h"

@implementation RadialGradientView

- (void) drawRect:(CGRect)rect {
    CGSize size = self.bounds.size;
    CGPoint center = CGPointMake(0.5 * size.width, 0.33 * size.height) ;

    CGContextRef cx = UIGraphicsGetCurrentContext();

    CGContextSaveGState(cx);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

    CGFloat comps[] = {1.0,1.0,1.0,1.0,
        0.95,0.95,0.95,1.0};
    CGFloat locs[] = {0,1};
    CGGradientRef g = CGGradientCreateWithColorComponents(space, comps, locs, 2);

    CGContextDrawRadialGradient(cx, g, center, 0.0f, center, size.width > size.height ? 0.5 * size.width : 0.5 * size.height, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);

    CGContextRestoreGState(cx);
}

@end
