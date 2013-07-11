//
//  BubbleViewToo.m
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleViewToo.h"

#import <QuartzCore/QuartzCore.h>

@implementation BubbleViewToo

- (id) init {
    self = [super init];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

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
    self.contentMode = UIViewContentModeRedraw;
    self.backgroundColor = [UIColor clearColor];
    self.colorScheme = HXOBubbleColorSchemeWhite;
    self.pointDirection = HXOBubblePointingRight;

    self.layer.shouldRasterize = YES;
    self.layer.shadowOffset = CGSizeMake(0.1, 2.1);
    [self configureDropShadow];
}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    _colorScheme = colorScheme;
    [self configureDropShadow];
}


- (void) configureDropShadow {
    BOOL hasShadow = self.colorScheme != HXOBubbleColorSchemeEtched;
    self.layer.shadowColor = hasShadow ? [UIColor blackColor].CGColor : NULL;
    self.layer.shadowOpacity = hasShadow ? 0.2 : 0;
    self.layer.shadowRadius = hasShadow ? 2 : 0;
}

- (void)drawRect:(CGRect)rect {
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    BOOL isEtched = self.colorScheme == HXOBubbleColorSchemeEtched;

    //// Color Declarations
    UIColor* bubbleFillColor = [self fillColor];
    UIColor* bubbleStrokeColor = [self strokeColor];
    CGFloat innerShadowAlpha = isEtched ? 0.15 : 0.07;
    UIColor* bubbleInnerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: innerShadowAlpha];

    //// Shadow Declarations
    UIColor* bubbleInnerShadow = bubbleInnerShadowColor;
    CGSize bubbleInnerShadowOffset = isEtched ? CGSizeMake(0.1, 2.1) : CGSizeMake(0.1, -2.1);
    CGFloat bubbleInnerShadowBlurRadius = isEtched ? 5 : 3;


    //// Bubble Drawing
    UIBezierPath* bubblePath = self.pointDirection == HXOBubblePointingRight ? [self rightPointingBubblePath] : [self leftPointingBubblePath];

    CGContextSaveGState(context);
    [bubbleFillColor setFill];
    [bubblePath fill];

    ////// Bubble Inner Shadow
    CGRect bubbleBorderRect = CGRectInset([bubblePath bounds], -bubbleInnerShadowBlurRadius, -bubbleInnerShadowBlurRadius);
    bubbleBorderRect = CGRectOffset(bubbleBorderRect, -bubbleInnerShadowOffset.width, -bubbleInnerShadowOffset.height);
    bubbleBorderRect = CGRectInset(CGRectUnion(bubbleBorderRect, [bubblePath bounds]), -1, -1);

    UIBezierPath* bubbleNegativePath = [UIBezierPath bezierPathWithRect: bubbleBorderRect];
    [bubbleNegativePath appendPath: bubblePath];
    bubbleNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = bubbleInnerShadowOffset.width + round(bubbleBorderRect.size.width);
        CGFloat yOffset = bubbleInnerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    bubbleInnerShadowBlurRadius,
                                    bubbleInnerShadow.CGColor);

        [bubblePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(bubbleBorderRect.size.width), 0);
        [bubbleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [bubbleNegativePath fill];
    }
    CGContextRestoreGState(context);


    CGContextRestoreGState(context);

    if (self.colorScheme != HXOBubbleColorSchemeEtched && self.colorScheme != HXOBubbleColorSchemeWhite) {
        [self drawInnerGlow: context path: bubblePath];
    }

    [bubbleStrokeColor setStroke];
    bubblePath.lineWidth = 1;
    [bubblePath stroke];
}

- (void) drawInnerGlow: (CGContextRef) context path: (UIBezierPath*) path {
    UIColor * innerGlowColor = [UIColor colorWithWhite: 1.0 alpha: 0.3];

    CGContextSaveGState(context);

    path.lineWidth = 3;
    path.lineJoinStyle = kCGLineJoinRound;

    [path addClip];

    [innerGlowColor setStroke];
    [path stroke];

    CGContextRestoreGState(context);
}

- (UIBezierPath*) rightPointingBubblePath {
    CGRect frame = self.bounds;

    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 27.57)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMaxY(frame) - 2)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 10, CGRectGetMaxY(frame) - 0.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMaxY(frame) - 0.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8.9, CGRectGetMaxY(frame) - 0.5)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 3, CGRectGetMaxY(frame) - 0.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMaxY(frame) - 2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1.9, CGRectGetMaxY(frame) - 0.5) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMaxY(frame) - 0.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 2.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 3, CGRectGetMinY(frame) + 0.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 1.4) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1.9, CGRectGetMinY(frame) + 0.5)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 10, CGRectGetMinY(frame) + 0.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 2.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8.9, CGRectGetMinY(frame) + 0.5) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 1.4)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 18.93)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 4.5, CGRectGetMinY(frame) + 20.51) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 20.03) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 6.04, CGRectGetMinY(frame) + 20.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 18.93) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 3.04, CGRectGetMinY(frame) + 20.51) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 20.03)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 27.57) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 23.21) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 3.99, CGRectGetMinY(frame) + 26.66)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIBezierPath*) leftPointingBubblePath {
    CGRect frame = self.bounds;

    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 27.57)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMaxY(frame) - 2)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 10, CGRectGetMaxY(frame) - 0.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMaxY(frame) - 0.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8.9, CGRectGetMaxY(frame) - 0.5)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 3, CGRectGetMaxY(frame) - 0.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMaxY(frame) - 2) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1.9, CGRectGetMaxY(frame) - 0.5) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMaxY(frame) - 0.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 2.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3, CGRectGetMinY(frame) + 0.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 1.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1.9, CGRectGetMinY(frame) + 0.5)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 10, CGRectGetMinY(frame) + 0.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 2.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8.9, CGRectGetMinY(frame) + 0.5) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 1.4)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 18.93)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 4.5, CGRectGetMinY(frame) + 20.51) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 20.03) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 6.04, CGRectGetMinY(frame) + 20.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 18.93) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 3.04, CGRectGetMinY(frame) + 20.51) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 20.03)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 27.57) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 23.21) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 3.99, CGRectGetMinY(frame) + 26.66)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIColor*) fillColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor whiteColor];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 0.996 green: 0.796 blue: 0.804 alpha: 1];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 0.855 green: 0.925 blue: 0.996 alpha: 1];
        case HXOBubbleColorSchemeBlack:
            return [UIColor colorWithRed: 0.19 green: 0.195 blue: 0.2 alpha: 1];
        case HXOBubbleColorSchemeEtched:
            return [UIColor colorWithWhite: 0.95 alpha: 1.0];
    }
}

- (UIColor*) strokeColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor colorWithWhite: 0.75 alpha: 1.0];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 0.792 green: 0.314 blue: 0.329 alpha: 1];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 0.49 green: 0.663 blue: 0.792 alpha: 1];
        case HXOBubbleColorSchemeBlack:
            return [UIColor colorWithRed: 0.19 green: 0.195 blue: 0.2 alpha: 1];
        case HXOBubbleColorSchemeEtched:
            return [UIColor whiteColor];
    }
}


@end
