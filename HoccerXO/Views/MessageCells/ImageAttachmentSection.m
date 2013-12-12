//
//  ImageAttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentSection.h"
#import "MessageCell.h"

extern CGFloat kHXOGridSpacing;

@implementation ImageAttachmentSection

- (void) commonInit {
    [super commonInit];

    self.subtitle.textAlignment = NSTextAlignmentCenter;
    self.subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.subtitle.frame = CGRectMake(0, self.bounds.size.height - 40, self.bounds.size.width, 40);
}

- (void) drawRect:(CGRect)rect {
    if (self.image != nil) {
        CGContextRef context = UIGraphicsGetCurrentContext();

        UIBezierPath * path = [self bubblePath];
        CGContextSaveGState(context);
        [path addClip];
        [self.image drawInRect: path.bounds];
        CGContextRestoreGState(context);
        if (self.cell.colorScheme == HXOBubbleColorSchemeFailed) {
            [[UIColor colorWithRed: 1.0 green: 0.0 blue: 0.0 alpha: 0.5] setFill];
            [path fill];
        }
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