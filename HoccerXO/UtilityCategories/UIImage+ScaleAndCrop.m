//
//  UIImage+ScaleAndCrop.m
//  HoccerTalk
//
//  Created by David Siegel on 30.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UIImage+ScaleAndCrop.h"

@implementation UIImage (ScaleAndCrop)

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize {
    UIImage *newImage = nil;
    CGFloat width = self.size.width;
    CGFloat height = self.size.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scale = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint origin = CGPointMake(0.0,0.0);

    if ( ! CGSizeEqualToSize(self.size, targetSize)) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;

        if (widthFactor > heightFactor) {
            scale = widthFactor; // scale to fit height
        } else {
            scale = heightFactor; // scale to fit width
        }

        scaledWidth  = width * scale;
        scaledHeight = height * scale;

        if (widthFactor > heightFactor) {
            origin.y = (targetHeight - scaledHeight) * 0.5;
        } else {
            origin.x = (targetWidth - scaledWidth) * 0.5;
        }
    }

    UIGraphicsBeginImageContext(targetSize);

    CGRect targetRect = CGRectZero;
    targetRect.origin = origin;
    targetRect.size.width  = scaledWidth;
    targetRect.size.height = scaledHeight;

    [self drawInRect:targetRect];

    newImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();
    
    return newImage;
}

- (void)drawInRect:(CGRect)drawRect fromRect:(CGRect)fromRect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha {
    CGImageRef drawImage = CGImageCreateWithImageInRect(self.CGImage, fromRect);
    if (drawImage != NULL) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);

        CGContextSetBlendMode(context, blendMode);
        CGContextSetAlpha(context, alpha);

        // Handle coordinate system flip
        CGContextTranslateCTM(context, 0, drawRect.origin.y + fromRect.size.height);
        CGContextScaleCTM(context, 1.0, -1.0);

        drawRect.origin.y = 0.0f;

        CGContextDrawImage(context, drawRect, drawImage);

        CGImageRelease(drawImage);
        CGContextRestoreGState(context);
    }
}

- (UIImage *)imageScaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
