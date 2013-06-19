//
//  PerforatedPlateView.m
//  HoccerXO
//
//  Created by David Siegel on 18.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "PerforatedPlateView.h"

@interface PerforatedPlateView ()
{
    UIImage * _logo;
    UIImage * _patternImage;
}
@end

@implementation PerforatedPlateView

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
    _patternImage = [UIImage imageNamed:@"background-tiles.png"];
    
    self.backgroundColor = [UIColor colorWithRed: 0.23 green: 0.24 blue: 0.26 alpha: 1];
    _logo = [UIImage imageNamed: @"xo"];
}

- (void) drawRect:(CGRect)rect {
    [super drawRect: rect];

    [self drawLogo];
}

- (void) drawLogo {
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* logoEmbossColor = [UIColor colorWithRed: 0.16 green: 0.168 blue: 0.184 alpha: 1];
    UIColor* logoInnerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.505];
    UIColor* logoOuterShadowColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.119];

    UIColor* holeEmbossColor = [UIColor colorWithRed: 0.192 green: 0.2 blue: 0.215 alpha: 1];


    //// Shadow Declarations
    UIColor* logoInnerShadow = logoInnerShadowColor;
    CGSize logoInnerShadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat logoInnerShadowBlurRadius = 4;
    UIColor* logoOuterShadow = logoOuterShadowColor;
    CGSize logoOuterShadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat logoOuterShadowBlurRadius = 0;

    //// Frames
    CGFloat width = 164;
    CGFloat y = self.bounds.size.width > self.bounds.size.height ? 30 : 105;
    CGRect frame = CGRectMake(0.5 * (self.bounds.size.width - width), y, width, 162);


    //// XLetter Drawing
    UIBezierPath* xLetterPath = [UIBezierPath bezierPath];
    [xLetterPath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 73)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 50, CGRectGetMinY(frame) + 62) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 73) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 50.11, CGRectGetMinY(frame) + 62.14)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 41, CGRectGetMinY(frame) + 70) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 46.65, CGRectGetMinY(frame) + 58.7) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 38.77, CGRectGetMinY(frame) + 67.83)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 53, CGRectGetMinY(frame) + 81) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 43.52, CGRectGetMinY(frame) + 72.78) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 53, CGRectGetMinY(frame) + 81)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 42, CGRectGetMinY(frame) + 92) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 53, CGRectGetMinY(frame) + 81) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 42.03, CGRectGetMinY(frame) + 91.96)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 50, CGRectGetMinY(frame) + 100) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 39.15, CGRectGetMinY(frame) + 94.89) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 47.53, CGRectGetMinY(frame) + 102.38)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 89) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 50.08, CGRectGetMinY(frame) + 99.91) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 89)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 72, CGRectGetMinY(frame) + 100) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 89) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 67.32, CGRectGetMinY(frame) + 95.43)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 80, CGRectGetMinY(frame) + 92) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 74.47, CGRectGetMinY(frame) + 102.35) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 83.1, CGRectGetMinY(frame) + 94.81)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 69, CGRectGetMinY(frame) + 81) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 80.07, CGRectGetMinY(frame) + 91.93) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 69, CGRectGetMinY(frame) + 81)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 80, CGRectGetMinY(frame) + 70) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 69, CGRectGetMinY(frame) + 81) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 80.05, CGRectGetMinY(frame) + 70.05)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 72, CGRectGetMinY(frame) + 62) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 82.26, CGRectGetMinY(frame) + 67.72) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 74.3, CGRectGetMinY(frame) + 59.6)];
    [xLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 73) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 72.16, CGRectGetMinY(frame) + 61.64) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 61, CGRectGetMinY(frame) + 73)];
    [xLetterPath closePath];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, logoOuterShadowOffset, logoOuterShadowBlurRadius, logoOuterShadow.CGColor);
    [logoEmbossColor setFill];
    [xLetterPath fill];

    ////// XLetter Inner Shadow
    CGRect xLetterBorderRect = CGRectInset([xLetterPath bounds], -logoInnerShadowBlurRadius, -logoInnerShadowBlurRadius);
    xLetterBorderRect = CGRectOffset(xLetterBorderRect, -logoInnerShadowOffset.width, -logoInnerShadowOffset.height);
    xLetterBorderRect = CGRectInset(CGRectUnion(xLetterBorderRect, [xLetterPath bounds]), -1, -1);

    UIBezierPath* xLetterNegativePath = [UIBezierPath bezierPathWithRect: xLetterBorderRect];
    [xLetterNegativePath appendPath: xLetterPath];
    xLetterNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = logoInnerShadowOffset.width + round(xLetterBorderRect.size.width);
        CGFloat yOffset = logoInnerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    logoInnerShadowBlurRadius,
                                    logoInnerShadow.CGColor);

        [xLetterPath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(xLetterBorderRect.size.width), 0);
        [xLetterNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [xLetterNegativePath fill];
    }
    CGContextRestoreGState(context);

    CGContextRestoreGState(context);



    //// OLetter Drawing
    UIBezierPath* oLetterPath = [UIBezierPath bezierPath];
    [oLetterPath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 101.2, CGRectGetMinY(frame) + 75.2)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 101.2, CGRectGetMinY(frame) + 85.8) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 98.27, CGRectGetMinY(frame) + 78.13) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 98.27, CGRectGetMinY(frame) + 82.87)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 111.8, CGRectGetMinY(frame) + 85.8) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 104.13, CGRectGetMinY(frame) + 88.73) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 108.87, CGRectGetMinY(frame) + 88.73)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 111.8, CGRectGetMinY(frame) + 75.2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 114.73, CGRectGetMinY(frame) + 82.87) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 114.73, CGRectGetMinY(frame) + 78.13)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 101.2, CGRectGetMinY(frame) + 75.2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 108.87, CGRectGetMinY(frame) + 72.27) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 104.13, CGRectGetMinY(frame) + 72.27)];
    [oLetterPath closePath];
    [oLetterPath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 121, CGRectGetMinY(frame) + 66.86)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 121, CGRectGetMinY(frame) + 95.14) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 129, CGRectGetMinY(frame) + 74.67) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 129, CGRectGetMinY(frame) + 87.33)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 92, CGRectGetMinY(frame) + 95.14) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 112.99, CGRectGetMinY(frame) + 102.95) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 100.01, CGRectGetMinY(frame) + 102.95)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 92, CGRectGetMinY(frame) + 66.86) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 84, CGRectGetMinY(frame) + 87.33) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 84, CGRectGetMinY(frame) + 74.67)];
    [oLetterPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 121, CGRectGetMinY(frame) + 66.86) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 100.01, CGRectGetMinY(frame) + 59.05) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 112.99, CGRectGetMinY(frame) + 59.05)];
    [oLetterPath closePath];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, logoOuterShadowOffset, logoOuterShadowBlurRadius, logoOuterShadow.CGColor);
    [logoEmbossColor setFill];
    [oLetterPath fill];

    ////// OLetter Inner Shadow
    CGRect oLetterBorderRect = CGRectInset([oLetterPath bounds], -logoInnerShadowBlurRadius, -logoInnerShadowBlurRadius);
    oLetterBorderRect = CGRectOffset(oLetterBorderRect, -logoInnerShadowOffset.width, -logoInnerShadowOffset.height);
    oLetterBorderRect = CGRectInset(CGRectUnion(oLetterBorderRect, [oLetterPath bounds]), -1, -1);

    UIBezierPath* oLetterNegativePath = [UIBezierPath bezierPathWithRect: oLetterBorderRect];
    [oLetterNegativePath appendPath: oLetterPath];
    oLetterNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = logoInnerShadowOffset.width + round(oLetterBorderRect.size.width);
        CGFloat yOffset = logoInnerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    logoInnerShadowBlurRadius,
                                    logoInnerShadow.CGColor);

        [oLetterPath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(oLetterBorderRect.size.width), 0);
        [oLetterNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [oLetterNegativePath fill];
    }
    CGContextRestoreGState(context);

    CGContextRestoreGState(context);



    //// Bubble Drawing
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 42.05, CGRectGetMinY(frame) + 41.76)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 32.73, CGRectGetMaxY(frame) - 53.8) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 24.86, CGRectGetMinY(frame) + 60.51) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 20.62, CGRectGetMaxY(frame) - 74.95)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 26, CGRectGetMaxY(frame) - 31) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 33.11, CGRectGetMaxY(frame) - 40.71) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 24.5, CGRectGetMaxY(frame) - 35.34)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 53, CGRectGetMaxY(frame) - 33) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 29.82, CGRectGetMaxY(frame) - 27.01) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 48.5, CGRectGetMaxY(frame) - 32.48)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 42.05, CGRectGetMaxY(frame) - 41.51) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 75.68, CGRectGetMaxY(frame) - 19.84) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 60.44, CGRectGetMaxY(frame) - 23.45)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 42, CGRectGetMinY(frame) + 41) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 19.98, CGRectGetMaxY(frame) - 63.18) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 19.94, CGRectGetMinY(frame) + 62.67)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 42.05, CGRectGetMinY(frame) + 41.76) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 64.06, CGRectGetMinY(frame) + 19.33) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 62.75, CGRectGetMinY(frame) + 19.18)];
    [bubblePath closePath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 34.27, CGRectGetMinY(frame) + 33.98)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 34.27, CGRectGetMaxY(frame) - 33.98) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7.91, CGRectGetMinY(frame) + 59.95) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7.91, CGRectGetMaxY(frame) - 59.95)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 48.66, CGRectGetMaxY(frame) - 23.16) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 56.24, CGRectGetMaxY(frame) - 12.33) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 74.42, CGRectGetMaxY(frame) - 8.73)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 15.5, CGRectGetMaxY(frame) - 25.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 43.28, CGRectGetMaxY(frame) - 22.54) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 22.82, CGRectGetMaxY(frame) - 17.92)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 23.14, CGRectGetMaxY(frame) - 48.41) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 13.53, CGRectGetMaxY(frame) - 32.09) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 21.18, CGRectGetMaxY(frame) - 40.88)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 34.27, CGRectGetMinY(frame) + 33.98) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 8.67, CGRectGetMaxY(frame) - 73.75) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 12.38, CGRectGetMinY(frame) + 55.55)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 34.27, CGRectGetMinY(frame) + 33.98) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 60.63, CGRectGetMinY(frame) + 8.01) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 60.63, CGRectGetMinY(frame) + 8.01)];
    [bubblePath closePath];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, logoOuterShadowOffset, logoOuterShadowBlurRadius, logoOuterShadow.CGColor);
    [logoEmbossColor setFill];
    [bubblePath fill];

    ////// Bubble Inner Shadow
    CGRect bubbleBorderRect = CGRectInset([bubblePath bounds], -logoInnerShadowBlurRadius, -logoInnerShadowBlurRadius);
    bubbleBorderRect = CGRectOffset(bubbleBorderRect, -logoInnerShadowOffset.width, -logoInnerShadowOffset.height);
    bubbleBorderRect = CGRectInset(CGRectUnion(bubbleBorderRect, [bubblePath bounds]), -1, -1);

    UIBezierPath* bubbleNegativePath = [UIBezierPath bezierPathWithRect: bubbleBorderRect];
    [bubbleNegativePath appendPath: bubblePath];
    bubbleNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = logoInnerShadowOffset.width + round(bubbleBorderRect.size.width);
        CGFloat yOffset = logoInnerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    logoInnerShadowBlurRadius,
                                    logoInnerShadow.CGColor);

        [bubblePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(bubbleBorderRect.size.width), 0);
        [bubbleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [bubbleNegativePath fill];
    }
    CGContextRestoreGState(context);

    CGContextRestoreGState(context);



    //// PerforationMask Drawing
    UIBezierPath* perforationMaskPath = [UIBezierPath bezierPath];
    [perforationMaskPath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 24.37, CGRectGetMinY(frame) + 24.08)];
    [perforationMaskPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 24.37, CGRectGetMaxY(frame) - 24.08) controlPoint1: CGPointMake(CGRectGetMaxX(frame) + 7.46, CGRectGetMinY(frame) + 55.52) controlPoint2: CGPointMake(CGRectGetMaxX(frame) + 7.46, CGRectGetMaxY(frame) - 55.52)];
    [perforationMaskPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 41.74, CGRectGetMaxY(frame) - 10.98) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 50.9, CGRectGetMaxY(frame) + 2.12) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 72.84, CGRectGetMaxY(frame) + 6.49)];
    [perforationMaskPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 1.71, CGRectGetMaxY(frame) - 13.82) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 35.25, CGRectGetMaxY(frame) - 10.23) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 10.55, CGRectGetMaxY(frame) - 4.64)];
    [perforationMaskPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 10.93, CGRectGetMaxY(frame) - 41.55) controlPoint1: CGPointMake(CGRectGetMinX(frame) - 0.67, CGRectGetMaxY(frame) - 21.8) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8.57, CGRectGetMaxY(frame) - 32.43)];
    [perforationMaskPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 24.37, CGRectGetMinY(frame) + 24.08) controlPoint1: CGPointMake(CGRectGetMinX(frame) - 6.54, CGRectGetMaxY(frame) - 72.23) controlPoint2: CGPointMake(CGRectGetMinX(frame) - 2.06, CGRectGetMinY(frame) + 50.19)];
    [perforationMaskPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 24.37, CGRectGetMinY(frame) + 24.08) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 56.2, CGRectGetMinY(frame) - 7.36) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 56.2, CGRectGetMinY(frame) - 7.36)];
    [perforationMaskPath closePath];

    
    //=================================================================================================================

    CGFloat radius = 2.5;
    CGSize offset = CGSizeMake(16, 9);
    NSUInteger rowCount = self.bounds.size.height / offset.height;
    NSUInteger columnCount =  (self.bounds.size.width / offset.width);
    CGFloat centerOffset = 0.5 * (self.bounds.size.width - columnCount * offset.width);
    CGPoint position = CGPointMake(0, 0.5 * offset.height);
    UIBezierPath* perforationPath = [UIBezierPath bezierPath];
    for (NSUInteger row = 0; row < rowCount; ++row) {
        if (row % 2 == 0) {
            position.x = centerOffset;
            columnCount = (self.bounds.size.width / offset.width) + 1;
        } else {
            position.x = centerOffset + 0.5 * offset.width;
            columnCount = (self.bounds.size.width / offset.width);
        }
        for (NSUInteger column = 0; column < columnCount; ++column) {
            if ( ! [perforationMaskPath containsPoint: position]) {
                [perforationPath moveToPoint: position];
                [perforationPath addArcWithCenter: position radius: radius startAngle:0 endAngle:2 * M_PI clockwise: NO];
                [perforationPath closePath];
            }
            position.x += offset.width;
        }
        position.y += offset.height;
    }


    CGRect boundingRect = CGContextGetClipBoundingBox(context);
    UIBezierPath * invertedPerforationPath = [UIBezierPath bezierPathWithRect:boundingRect];
    [invertedPerforationPath appendPath: perforationPath];
    invertedPerforationPath.usesEvenOddFillRule = YES;

    [holeEmbossColor setFill];
    [perforationPath fill];

    CGContextSaveGState(context);
    {
        [perforationPath addClip];
        [[UIColor blackColor] setFill];
        CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1.0, logoInnerShadowColor.CGColor);
        [invertedPerforationPath fill];
    }
    CGContextRestoreGState(context);


    CGContextSaveGState(context);
    {

        [invertedPerforationPath addClip];
        [[UIColor blackColor] setFill];
        CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1.0, logoOuterShadowColor.CGColor);
        [perforationPath fill];
    }
    CGContextRestoreGState(context);

}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}
@end
