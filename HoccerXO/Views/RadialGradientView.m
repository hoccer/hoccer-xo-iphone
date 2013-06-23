//
//  RadialGradientView.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "RadialGradientView.h"

@implementation RadialGradientView

- (void) drawRect:(CGRect)rect {
    CGSize size = self.bounds.size;
    CGPoint center = CGPointMake(0.5 * size.width, 0.33 * size.height) ;

    CGContextRef context = UIGraphicsGetCurrentContext();

    [RadialGradientView drawInContext: context withSize: size andCenter: center];
}

+ (void) drawInContext: (CGContextRef) context withSize: (CGSize) size andCenter: (CGPoint) center {
    CGContextSaveGState(context);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

    CGFloat components[] = {1.0,1.0,1.0,1.0,
        0.95,0.95,0.95,1.0};


    CGFloat locs[] = {0,1};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locs, 2);

    CGContextDrawRadialGradient(context, gradient, center, 0.0f, center, size.width > size.height ? 0.5 * size.width : 0.5 * size.height, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);

    CGContextRestoreGState(context);
}
@end
