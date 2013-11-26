//
//  ProfileAvatarView.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileAvatarView.h"

#import <QuartzCore/QuartzCore.h>

@implementation ProfileAvatarView

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    //// Image Declarations
    UIImage* image = self.image != nil ? self.image : self.defaultImage;

    //// Frames
    CGRect frame = CGRectInset(self.bounds, -10, -10);
    


    CGContextRef context = UIGraphicsGetCurrentContext();


    //// Oval Drawing
    CGRect ovalRect = CGRectMake(CGRectGetMinX(frame) + 43, CGRectGetMinY(frame) + 43, CGRectGetWidth(frame) - 86, CGRectGetHeight(frame) - 86);
    UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect: ovalRect];
    CGContextSaveGState(context);
    [ovalPath addClip];
    [image drawInRect: ovalRect];
    CGContextRestoreGState(context);
}

- (void) setOuterShadowColor:(UIColor *)outerShadowColor {
    _outerShadowColor = outerShadowColor;
    [self setNeedsDisplay];
}
- (void) setImage:(UIImage *)image {
    _image = image;
    [self setNeedsDisplay];
}

@end
