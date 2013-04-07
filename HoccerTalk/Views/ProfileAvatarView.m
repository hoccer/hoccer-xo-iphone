//
//  ProfileAvatarView.m
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileAvatarView.h"

@implementation ProfileAvatarView



- (void) drawRect:(CGRect)rect {
    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* gardientBottom = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    UIColor* gradientTop = [UIColor colorWithRed: 0.851 green: 0.851 blue: 0.851 alpha: 1];
    UIColor* shadowColor2 = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];

    //// Gradient Declarations
    NSArray* gradientColors = [NSArray arrayWithObjects:
                               (id)gradientTop.CGColor,
                               (id)gardientBottom.CGColor, nil];
    CGFloat gradientLocations[] = {0, 1};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, gradientLocations);

    //// Shadow Declarations
    UIColor* shadow = shadowColor2;
    CGSize shadowOffset = CGSizeMake(0.1, 3.1);
    CGFloat shadowBlurRadius = 7.5;

    //// Image Declarations
    UIImage* image = self.image;

    //// Frames
    CGRect frame = self.bounds;


    //// Oval 2 Drawing
    CGRect oval2Rect = CGRectMake(CGRectGetMinX(frame) + 9, CGRectGetMinY(frame) + 11, CGRectGetWidth(frame) - 17, CGRectGetHeight(frame) - 17);
    UIBezierPath* oval2Path = [UIBezierPath bezierPathWithOvalInRect: oval2Rect];
    CGContextSaveGState(context);
    [oval2Path addClip];
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(CGRectGetMidX(oval2Rect), CGRectGetMinY(oval2Rect)),
                                CGPointMake(CGRectGetMidX(oval2Rect), CGRectGetMaxY(oval2Rect)),
                                0);
    CGContextRestoreGState(context);


    //// Oval Drawing
    CGRect ovalRect = CGRectMake(CGRectGetMinX(frame) + 24, CGRectGetMinY(frame) + 26, CGRectGetWidth(frame) - 47, CGRectGetHeight(frame) - 47);
    UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: ovalRect];
    CGContextSaveGState(context);
    [ovalPath addClip];
    [image drawInRect: CGRectMake(floor(CGRectGetMinX(ovalRect) + 0.5), floor(CGRectGetMinY(ovalRect) - 8 + 0.5), image.size.width, image.size.height)];
    CGContextRestoreGState(context);

    ////// Oval Inner Shadow
    CGRect ovalBorderRect = CGRectInset([ovalPath bounds], -shadowBlurRadius, -shadowBlurRadius);
    ovalBorderRect = CGRectOffset(ovalBorderRect, -shadowOffset.width, -shadowOffset.height);
    ovalBorderRect = CGRectInset(CGRectUnion(ovalBorderRect, [ovalPath bounds]), -1, -1);

    UIBezierPath* ovalNegativePath = [UIBezierPath bezierPathWithRect: ovalBorderRect];
    [ovalNegativePath appendPath: ovalPath];
    ovalNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = shadowOffset.width + round(ovalBorderRect.size.width);
        CGFloat yOffset = shadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    shadowBlurRadius,
                                    shadow.CGColor);
        
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
