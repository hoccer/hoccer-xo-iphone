//
//  ProfileAvatarView.m
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileAvatarView.h"

#import <QuartzCore/QuartzCore.h>

@implementation ProfileAvatarView

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* gardientBottom = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientTop = [UIColor colorWithRed: 0.851 green: 0.851 blue: 0.851 alpha: 1];
    UIColor* innerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.536];
    UIColor* outerShadowColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];

    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientTop.CGColor,
                               (id)gardientBottom.CGColor, nil];
    CGFloat gradientLocations[] = {0, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, gradientLocations);

    //// Shadow Declarations
    UIColor* innerShadow = innerShadowColor;
    CGSize innerShadowOffset = CGSizeMake(0.1, 5.1);
    CGFloat innerShadowBlurRadius = 5;
    UIColor* outerShadow = outerShadowColor;
    CGSize outerShadowOffset = CGSizeMake(0.1, -0.1);
    CGFloat outerShadowBlurRadius = 20;

    //// Image Declarations
    UIImage* image = self.image;

    //// Frames
    CGRect frame = self.bounds;


    //// Oval 2 Drawing
    CGRect oval2Rect = CGRectMake(CGRectGetMinX(frame) + 17, CGRectGetMinY(frame) + 17, CGRectGetWidth(frame) - 34, CGRectGetHeight(frame) - 34);
    UIBezierPath* oval2Path = [UIBezierPath bezierPathWithOvalInRect: oval2Rect];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, outerShadowOffset, outerShadowBlurRadius, outerShadow.CGColor);
    CGContextBeginTransparencyLayer(context, NULL);
    [oval2Path addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(oval2Rect), CGRectGetMinY(oval2Rect)),
                                CGPointMake(CGRectGetMidX(oval2Rect), CGRectGetMaxY(oval2Rect)),
                                0);
    CGContextEndTransparencyLayer(context);
    CGContextRestoreGState(context);



    //// Oval Drawing
    CGRect ovalRect = CGRectMake(CGRectGetMinX(frame) + 28, CGRectGetMinY(frame) + 28, CGRectGetWidth(frame) - 56, CGRectGetHeight(frame) - 56);
    UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: ovalRect];
    CGContextSaveGState(context);
    [ovalPath addClip];
    [image drawInRect: CGRectMake(floor(CGRectGetMinX(ovalRect) + 0.5), floor(CGRectGetMinY(ovalRect) + 0.5), ovalRect.size.width, ovalRect.size.height)];
    CGContextRestoreGState(context);

    ////// Oval Inner Shadow
    CGRect ovalBorderRect = CGRectInset([ovalPath bounds], -innerShadowBlurRadius, -innerShadowBlurRadius);
    ovalBorderRect = CGRectOffset(ovalBorderRect, -innerShadowOffset.width, -innerShadowOffset.height);
    ovalBorderRect = CGRectInset(CGRectUnion(ovalBorderRect, [ovalPath bounds]), -1, -1);

    UIBezierPath* ovalNegativePath = [UIBezierPath bezierPathWithRect: ovalBorderRect];
    [ovalNegativePath appendPath: ovalPath];
    ovalNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = innerShadowOffset.width + round(ovalBorderRect.size.width);
        CGFloat yOffset = innerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    innerShadowBlurRadius,
                                    innerShadow.CGColor);
        
        [ovalPath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(ovalBorderRect.size.width), 0);
        [ovalNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [ovalNegativePath fill];
    }
    CGContextRestoreGState(context);
    
    
    
    //// Cleanup
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    

}

@end
