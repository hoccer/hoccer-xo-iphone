//
//  ImageAttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentSection.h"

extern CGFloat kHXOGridSpacing;

@implementation ImageAttachmentSection

- (void) drawRect:(CGRect)rect {
    if (self.image != nil) {
        CGContextRef context = UIGraphicsGetCurrentContext();

        UIBezierPath * path = [self bubblePath];
        CGContextSaveGState(context);
        [path addClip];
        [self.image drawInRect: path.bounds];
        CGContextRestoreGState(context);
    } else {
        [super drawRect:rect];
    }
}

- (CGSize) sizeThatFits:(CGSize)size {
    size.width -= 2 * kHXOGridSpacing;
    CGFloat aspect = self.image != nil ? self.image.size.width / self.image.size.height : self.imageAspect;

    size.height = size.width / aspect;
    size.width += 2 * kHXOGridSpacing;
    return size;
}


@end