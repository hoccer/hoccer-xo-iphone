//
//  UIImage+Tint.m
//  HoccerXO
//
//  Created by Guido Lorenz on 13.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "UIImage+Tint.h"

@implementation UIImage (Tint)

- (UIImage *) tintWithColor:(UIColor *)color
{
    CGImageRef maskImage = self.CGImage;
    CGFloat width = self.size.width * self.scale;
    CGFloat height = self.size.height * self.scale;
    CGRect bounds = CGRectMake(0, 0, width, height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextClipToMask(bitmapContext, bounds, maskImage);
    CGContextSetFillColorWithColor(bitmapContext, color.CGColor);
    CGContextFillRect(bitmapContext, bounds);
    
    CGImageRef cImage = CGBitmapContextCreateImage(bitmapContext);
    UIImage *tintedImage = [UIImage imageWithCGImage:cImage scale:self.scale orientation:self.imageOrientation];
    
    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cImage);
    
    return tintedImage;
}

@end
