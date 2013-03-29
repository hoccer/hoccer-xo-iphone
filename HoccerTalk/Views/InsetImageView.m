//
//  AvatarView.m
//  HoccerTalk
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InsetImageView.h"

#import <QuartzCore/QuartzCore.h>

#import "UIImage+ScaleAndCrop.h"

@implementation InsetImageView
{
    UIImage * _resizedImage;
}

- (id) init {
    self = [super init];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

    _borderColor = [UIColor colorWithWhite: 0.1 alpha: 1.0];
    _shadowColor = [UIColor colorWithWhite:0 alpha: 0.6];
    _insetColor = [UIColor whiteColor];

    _shadowOffset = CGSizeMake(0.1, 1.1);
    _shadowBlurRadius = 1;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self resizeImage];
}

- (void) setImage:(UIImage *)image {
    _image = image;
    [self resizeImage];
}

- (void) resizeImage {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize targetSize = CGSizeMake(scale * (self.bounds.size.width - 2), scale * (self.bounds.size.height - 3));
    _resizedImage = [_image imageByScalingAndCroppingForSize: targetSize];
}

- (void) drawRect: (CGRect)rect {
    CGRect insetRectangleRect = CGRectMake(0.5, 1.5, self.bounds.size.width -1, self.bounds.size.height -2);
    CGFloat insetRectangleCornerRadius = 4;
    CGRect borderRectangleRect = CGRectMake(0.5, 0.5, self.bounds.size.width -1, self.bounds.size.height -2);
    CGFloat borderRectangleCornerRadius = 4;

    CGContextRef context = UIGraphicsGetCurrentContext();

    // Inset Rectangle Drawing
    UIBezierPath* insetRectanglePath = [UIBezierPath bezierPathWithRoundedRect: insetRectangleRect cornerRadius: insetRectangleCornerRadius];
    [_insetColor setFill];
    [insetRectanglePath fill];
    [_insetColor setStroke];
    insetRectanglePath.lineWidth = 1;
    [insetRectanglePath stroke];

    // Border Rectangle Drawing
    UIBezierPath* borderRectanglePath = [UIBezierPath bezierPathWithRoundedRect: borderRectangleRect cornerRadius: borderRectangleCornerRadius];
    CGContextSaveGState(context);
    [borderRectanglePath addClip];
    [_resizedImage drawInRect: borderRectangleRect];
    CGContextRestoreGState(context);

    // Border Rectangle Inner Shadow
    CGRect borderRectangleBorderRect = CGRectInset([borderRectanglePath bounds], -_shadowBlurRadius, -_shadowBlurRadius);
    borderRectangleBorderRect = CGRectOffset(borderRectangleBorderRect, -_shadowOffset.width, -_shadowOffset.height);
    borderRectangleBorderRect = CGRectInset(CGRectUnion(borderRectangleBorderRect, [borderRectanglePath bounds]), -1, -1);

    UIBezierPath* borderRectangleNegativePath = [UIBezierPath bezierPathWithRect: borderRectangleBorderRect];
    [borderRectangleNegativePath appendPath: borderRectanglePath];
    borderRectangleNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = _shadowOffset.width + round(borderRectangleBorderRect.size.width);
        CGFloat yOffset = _shadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    _shadowBlurRadius,
                                    _shadowColor.CGColor);

        [borderRectanglePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(borderRectangleBorderRect.size.width), 0);
        [borderRectangleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [borderRectangleNegativePath fill];
    }
    CGContextRestoreGState(context);
    
    [_borderColor setStroke];
    borderRectanglePath.lineWidth = 1;
    [borderRectanglePath stroke];
}

@end
