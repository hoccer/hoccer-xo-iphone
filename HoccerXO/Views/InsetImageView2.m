//
//  InsetImageView2.m
//  HoccerXO
//
//  Created by David Siegel on 29.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InsetImageView2.h"

@implementation InsetImageView2

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

}

- (void)drawRect:(CGRect)rect {

    CGRect frame = CGRectInset(self.bounds, 1, 1);
    UIImage* image = self.image;


    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* innerStrokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.2];
    UIColor* outerStrokeColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1.0];
    UIColor* innerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.3];

    //// Shadow Declarations
    UIColor* innerShadow = innerShadowColor;
    CGSize innerShadowOffset = CGSizeMake(0.1, 2.1);
    CGFloat innerShadowBlurRadius = 2;

    //// Image Declarations


    //// Abstracted Attributes
    CGFloat roundedRectangleCornerRadius = 4;


    //// Rounded Rectangle Drawing
    CGRect roundedRectangleRect = CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame), CGRectGetWidth(frame), CGRectGetHeight(frame));


    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect: roundedRectangleRect cornerRadius: roundedRectangleCornerRadius];

    [outerStrokeColor setStroke];
    roundedRectanglePath.lineWidth = 2;
    [roundedRectanglePath stroke];




    CGContextSaveGState(context);
    [roundedRectanglePath addClip];

    if (image != nil) {
        [image drawInRect: [self imageRectForRect: roundedRectangleRect]];
    } else {
        [[UIColor clearColor] setFill];
        [roundedRectanglePath fill];
    }
    CGContextRestoreGState(context);


    ////// Rounded Rectangle Inner Shadow
    CGRect roundedRectangleBorderRect = CGRectInset([roundedRectanglePath bounds], -innerShadowBlurRadius, -innerShadowBlurRadius);
    roundedRectangleBorderRect = CGRectOffset(roundedRectangleBorderRect, -innerShadowOffset.width, -innerShadowOffset.height);
    roundedRectangleBorderRect = CGRectInset(CGRectUnion(roundedRectangleBorderRect, [roundedRectanglePath bounds]), -1, -1);

    UIBezierPath* roundedRectangleNegativePath = [UIBezierPath bezierPathWithRect: roundedRectangleBorderRect];
    [roundedRectangleNegativePath appendPath: roundedRectanglePath];
    roundedRectangleNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = innerShadowOffset.width + round(roundedRectangleBorderRect.size.width);
        CGFloat yOffset = innerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    innerShadowBlurRadius,
                                    innerShadow.CGColor);

        [roundedRectanglePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(roundedRectangleBorderRect.size.width), 0);
        [roundedRectangleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [roundedRectangleNegativePath fill];
    }
    CGContextRestoreGState(context);



    CGContextSaveGState(context);

    [roundedRectanglePath addClip];

    [innerStrokeColor setStroke];
    roundedRectanglePath.lineWidth = 2;
    [roundedRectanglePath stroke];

    CGContextRestoreGState(context);

    

    
}

- (CGRect) imageRectForRect: (CGRect) frame {
    CGFloat scale;
    if (self.image.size.width > self.image.size.height) {
        scale = self.bounds.size.height / self.image.size.height;
    } else {
        scale = self.bounds.size.width / self.image.size.width;
    }
    return CGRectMake(floor(CGRectGetMinX(frame) + 0.5), floor(CGRectGetMinY(frame) + 0.5), scale * self.image.size.width, scale * self.image.size.height);
}

@end
