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

}

- (void)drawRect:(CGRect)rect {



    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* bubbleFillColor = [UIColor colorWithRed: 0.19 green: 0.195 blue: 0.2 alpha: 1];
    UIColor* bubbleDropShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.1];
    UIColor* bubbleStrokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];

    //// Shadow Declarations
    UIColor* bubbleDropShadow = bubbleDropShadowColor;
    CGSize bubbleDropShadowOffset = CGSizeMake(0.1, 2.1);
    CGFloat bubbleDropShadowBlurRadius = 2;

    //// Bubble Drawing
    UIBezierPath* bubblePath = [self leftPointingBubblePath];

    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, bubbleDropShadowOffset, bubbleDropShadowBlurRadius, bubbleDropShadow.CGColor);
    [bubbleFillColor setFill];
    [bubblePath fill];
    CGContextRestoreGState(context);

    [self drawInnerGlow: context path: bubblePath];

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
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMaxY(frame) - 3)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 10, CGRectGetMaxY(frame) - 1) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 8, CGRectGetMaxY(frame) - 1.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8.9, CGRectGetMaxY(frame) - 1)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 3, CGRectGetMaxY(frame) - 1)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMaxY(frame) - 3) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1.9, CGRectGetMaxY(frame) - 1) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 1, CGRectGetMaxY(frame) - 1.9)];
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
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMaxY(frame) - 3)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 10, CGRectGetMaxY(frame) - 1) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8, CGRectGetMaxY(frame) - 1.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8.9, CGRectGetMaxY(frame) - 1)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 3, CGRectGetMaxY(frame) - 1)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMaxY(frame) - 3) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1.9, CGRectGetMaxY(frame) - 1) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 1, CGRectGetMaxY(frame) - 1.9)];
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

@end
