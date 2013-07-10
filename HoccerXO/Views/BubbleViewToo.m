//
//  BubbleViewToo.m
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleViewToo.h"

@implementation BubbleViewToo

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
    self.backgroundColor = [UIColor clearColor];
    self.colorScheme = HXOBubbleColorSchemeWhite;
    self.pointDirection = HXOBubblePointingRight;
}

- (void)drawRect:(CGRect)rect {
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* bubbleFillColor = [self fillColor];
    UIColor* bubbleStrokeColor = [self strokeColor];
    UIColor* bubbleDropShadowColor = [UIColor colorWithWhite: 0 alpha: 0.1];
    UIColor* bubbleInnerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.07];

    //// Shadow Declarations
    UIColor* bubbleDropShadow = bubbleDropShadowColor;
    CGSize bubbleDropShadowOffset = CGSizeMake(0.1, 2.1);
    CGFloat bubbleDropShadowBlurRadius = 2;
    UIColor* bubbleInnerShadow = bubbleInnerShadowColor;
    CGSize bubbleInnerShadowOffset =  self.colorScheme == HXOBubbleColorSchemeEtched ? CGSizeMake(0.1, 5.1) : CGSizeMake(0.1, -5.1);
    CGFloat bubbleInnerShadowBlurRadius = 5;


    //// Bubble Drawing
    UIBezierPath* bubblePath = self.pointDirection == HXOBubblePointingRight ? [self rightPointingBubblePath] : [self leftPointingBubblePath];

    CGContextSaveGState(context);
    if (self.colorScheme != HXOBubbleColorSchemeEtched) {
        CGContextSetShadowWithColor(context, bubbleDropShadowOffset, bubbleDropShadowBlurRadius, bubbleDropShadow.CGColor);
    }
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
    [bubblePath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 28.07)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMaxY(frame) - 5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 10, CGRectGetMaxY(frame) - 3) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMaxY(frame) - 3.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8.9, CGRectGetMaxY(frame) - 3)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 3, CGRectGetMaxY(frame) - 3)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMaxY(frame) - 5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1.9, CGRectGetMaxY(frame) - 3) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMaxY(frame) - 3.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 3)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 3, CGRectGetMinY(frame) + 1) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 1.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1.9, CGRectGetMinY(frame) + 1)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 10, CGRectGetMinY(frame) + 1)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 3) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8.9, CGRectGetMinY(frame) + 1) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 1.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 19.43)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 4.5, CGRectGetMinY(frame) + 21.01) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 20.53) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 6.04, CGRectGetMinY(frame) + 21)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 19.43) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 3.04, CGRectGetMinY(frame) + 21.01) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 20.53)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMinY(frame) + 28.07) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 23.71) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 3.99, CGRectGetMinY(frame) + 27.16)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIBezierPath*) leftPointingBubblePath {
    CGRect frame = self.bounds;

    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 28.07)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMaxY(frame) - 5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 10, CGRectGetMaxY(frame) - 3) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMaxY(frame) - 3.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8.9, CGRectGetMaxY(frame) - 3)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 3, CGRectGetMaxY(frame) - 3)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMaxY(frame) - 5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1.9, CGRectGetMaxY(frame) - 3) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMaxY(frame) - 3.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 3)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3, CGRectGetMinY(frame) + 1) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMinY(frame) + 1.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1.9, CGRectGetMinY(frame) + 1)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 10, CGRectGetMinY(frame) + 1)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 3) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8.9, CGRectGetMinY(frame) + 1) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 1.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 19.43)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 4.5, CGRectGetMinY(frame) + 21.01) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 20.53) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 6.04, CGRectGetMinY(frame) + 21)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 19.43) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 3.04, CGRectGetMinY(frame) + 21.01) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 20.53)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMinY(frame) + 28.07) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMinY(frame) + 23.71) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 3.99, CGRectGetMinY(frame) + 27.16)];
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
            return [UIColor colorWithWhite: 0.92 alpha: 1.0];
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
