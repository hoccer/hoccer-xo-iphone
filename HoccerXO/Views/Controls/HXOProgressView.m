//
//  HXOProgressView.m
//  HoccerXO
//
//  Created by David Siegel on 19.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOProgressView.h"

static const CGFloat kHXOProgressViewSize = 14.0;


static UIImage * HXOProgressViewTrackImage = NULL;
static UIImage * HXOProgressViewProgressImage = NULL;

@implementation HXOProgressView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.trackImage = [self getTrackImage];
    self.progressImage = [self getProgressImage];

    CGRect frame = self.frame;
    frame.size.height = kHXOProgressViewSize;
    self.frame = frame;
}

- (UIImage*) getTrackImage {
    if (HXOProgressViewTrackImage == NULL) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kHXOProgressViewSize, kHXOProgressViewSize), NO, [UIScreen mainScreen].scale);
        CGRect frame = CGRectMake(0, 0, kHXOProgressViewSize, kHXOProgressViewSize);


        //// General Declarations
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = UIGraphicsGetCurrentContext();

        //// Color Declarations
        UIColor* outlineColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.15];
        UIColor* borderColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
        UIColor* darkGradientColor = [UIColor colorWithRed: 0.11 green: 0.11 blue: 0.11 alpha: 1];
        UIColor* lightGradientColor = [UIColor colorWithRed: 0.141 green: 0.141 blue: 0.141 alpha: 1];
        UIColor* innerGlowColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.1];

        //// Gradient Declarations
        NSArray* gradientColors = [NSArray arrayWithObjects:
                                   (id)darkGradientColor.CGColor,
                                   (id)lightGradientColor.CGColor, nil];
        CGFloat gradientLocations[] = {0, 1};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, gradientLocations);

        //// Shadow Declarations
        UIColor* shadow = borderColor;
        CGSize shadowOffset = CGSizeMake(0.1, 2.1);
        CGFloat shadowBlurRadius = 2;

        //// Outline Drawing
        UIBezierPath* outlinePath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(frame) + 0.5, CGRectGetMinY(frame) + 0.5, CGRectGetWidth(frame) - 1, CGRectGetHeight(frame) - 1)];
        [outlineColor setStroke];
        outlinePath.lineWidth = 1;
        [outlinePath stroke];


        //// Track Drawing
        CGRect trackRect = CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 3);
        UIBezierPath* trackPath = [UIBezierPath bezierPathWithOvalInRect: trackRect];
        CGContextSaveGState(context);
        [trackPath addClip];
        CGContextDrawLinearGradient(context, gradient,
                                    CGPointMake(CGRectGetMidX(trackRect), CGRectGetMinY(trackRect)),
                                    CGPointMake(CGRectGetMidX(trackRect), CGRectGetMaxY(trackRect)),
                                    0);
        CGContextRestoreGState(context);



        //// Inner Glow Drawing
        CGContextSaveGState(context);
        [trackPath addClip];
        UIBezierPath* innerGlowPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(frame) + 1.5, CGRectGetMinY(frame) + 0.5, CGRectGetWidth(frame) - 3, CGRectGetHeight(frame) - 3)];
        [innerGlowColor setStroke];
        innerGlowPath.lineWidth = 1;
        [innerGlowPath stroke];
        CGContextRestoreGState(context);


        ////// Track Inner Shadow
        CGRect trackBorderRect = CGRectInset([trackPath bounds], -shadowBlurRadius, -shadowBlurRadius);
        trackBorderRect = CGRectOffset(trackBorderRect, -shadowOffset.width, -shadowOffset.height);
        trackBorderRect = CGRectInset(CGRectUnion(trackBorderRect, [trackPath bounds]), -1, -1);

        UIBezierPath* trackNegativePath = [UIBezierPath bezierPathWithRect: trackBorderRect];
        [trackNegativePath appendPath: trackPath];
        trackNegativePath.usesEvenOddFillRule = YES;

        CGContextSaveGState(context);
        {
            CGFloat xOffset = shadowOffset.width + round(trackBorderRect.size.width);
            CGFloat yOffset = shadowOffset.height;
            CGContextSetShadowWithColor(context,
                                        CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                        shadowBlurRadius,
                                        shadow.CGColor);

            [trackPath addClip];
            CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(trackBorderRect.size.width), 0);
            [trackNegativePath applyTransform: transform];
            [[UIColor grayColor] setFill];
            [trackNegativePath fill];
        }
        CGContextRestoreGState(context);
        
        [borderColor setStroke];
        trackPath.lineWidth = 1;
        [trackPath stroke];
        
        
        //// Cleanup
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        

        HXOProgressViewTrackImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:floorf(0.5 * kHXOProgressViewSize) topCapHeight:0];
        
        UIGraphicsEndImageContext();
    }
    return HXOProgressViewTrackImage;
}

- (UIImage*) getProgressImage {
    if (HXOProgressViewProgressImage == NULL) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kHXOProgressViewSize, kHXOProgressViewSize), NO, [UIScreen mainScreen].scale);
        CGRect frame = CGRectMake(0, 0, kHXOProgressViewSize, kHXOProgressViewSize);


        //// General Declarations
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = UIGraphicsGetCurrentContext();

        //// Color Declarations
        UIColor* borderColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
        UIColor* topGradientColor = [UIColor colorWithRed: 0.427 green: 0.871 blue: 0.796 alpha: 1];
        UIColor* lightGradientColor = [UIColor colorWithRed: 0.149 green: 0.588 blue: 0.541 alpha: 1];
        UIColor* lowerInnerGlowColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.25];
        UIColor* upperInnerGlowColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.75];

        //// Gradient Declarations
        NSArray* gradientColors = [NSArray arrayWithObjects:
                                   (id)topGradientColor.CGColor,
                                   (id)lightGradientColor.CGColor, nil];
        CGFloat gradientLocations[] = {0, 1};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, gradientLocations);

        //// Progress Drawing
        CGRect progressRect = CGRectMake(CGRectGetMinX(frame) + 2.5, CGRectGetMinY(frame) + 2.5, CGRectGetWidth(frame) - 5, CGRectGetHeight(frame) - 5);
        UIBezierPath* progressPath = [UIBezierPath bezierPathWithOvalInRect: progressRect];
        CGContextSaveGState(context);
        [progressPath addClip];
        CGContextDrawLinearGradient(context, gradient,
                                    CGPointMake(CGRectGetMidX(progressRect), CGRectGetMinY(progressRect)),
                                    CGPointMake(CGRectGetMidX(progressRect), CGRectGetMaxY(progressRect)),
                                    0);
        CGContextRestoreGState(context);

        CGContextSaveGState(context);

        [progressPath addClip];

        //// Lower Inner Glow Drawing
        UIBezierPath* lowerInnerGlowPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(frame) + 2.5, CGRectGetMinY(frame) + 1.5, CGRectGetWidth(frame) - 5, CGRectGetHeight(frame) - 5)];
        [lowerInnerGlowColor setStroke];
        lowerInnerGlowPath.lineWidth = 1;
        [lowerInnerGlowPath stroke];


        //// Upper Inner Glow Drawing
        UIBezierPath* upperInnerGlowPath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(CGRectGetMinX(frame) + 2.5, CGRectGetMinY(frame) + 3.5, CGRectGetWidth(frame) - 5, CGRectGetHeight(frame) - 5)];
        [upperInnerGlowColor setStroke];
        upperInnerGlowPath.lineWidth = 1;
        [upperInnerGlowPath stroke];

        CGContextRestoreGState(context);


        [borderColor setStroke];
        progressPath.lineWidth = 1;
        [progressPath stroke];


        //// Cleanup
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        

        HXOProgressViewProgressImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:floorf(0.5 * kHXOProgressViewSize) topCapHeight:0];

        UIGraphicsEndImageContext();
    }
    return HXOProgressViewProgressImage;
}

@end
