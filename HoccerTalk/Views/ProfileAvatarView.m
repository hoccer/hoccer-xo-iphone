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

        self.gradientBottomColor = [UIColor whiteColor];
        self.gradientTopColor    = [UIColor colorWithWhite: 0.85 alpha: 1];
        
        self.innerShadowColor    = [UIColor colorWithWhite: 0 alpha: 0.5];
        self.innerShadowOffset = CGSizeMake(0.1, 5.1);
        self.innerShadowBlurRadius = 5;

        self.outerShadowColor    = [UIColor whiteColor];
        self.outerShadowOffset = CGSizeMake(0.1, -0.1);
        self.outerShadowBlurRadius = 20;

    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    //// Color Declarations
    UIColor* gardientBottom = self.gradientBottomColor;
    UIColor* gradientTop = self.gradientTopColor;
    UIColor* innerShadowColor = self.innerShadowColor;
    UIColor* outerShadowColor = self.outerShadowColor;

    //// Shadow Declarations
    UIColor* innerShadow = innerShadowColor;
    CGSize innerShadowOffset = self.innerShadowOffset;
    CGFloat innerShadowBlurRadius = self.innerShadowBlurRadius;
    UIColor* outerShadow = outerShadowColor;
    CGSize outerShadowOffset = self.outerShadowOffset;
    CGFloat outerShadowBlurRadius = self.outerShadowBlurRadius;

    //// Image Declarations
    UIImage* image = self.image;

    //// Frames
    CGRect frame = self.bounds;
    


    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();


    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientTop.CGColor,
                               (id)gardientBottom.CGColor, nil];
    CGFloat gradientLocations[] = {0, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, gradientLocations);


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

- (void) setOuterShadowColor:(UIColor *)outerShadowColor {
    _outerShadowColor = outerShadowColor;
    [self setNeedsDisplay];
}

@end
