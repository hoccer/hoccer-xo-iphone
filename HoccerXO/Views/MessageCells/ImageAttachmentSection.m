//
//  ImageAttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentSection.h"
#import "MessageCell.h"
#import "HXOUpDownLoadControl.h"

extern CGFloat kHXOGridSpacing;

@implementation ImageAttachmentSection

- (void) commonInit {
    [super commonInit];

    self.subtitle.textAlignment = NSTextAlignmentCenter;
    self.subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.subtitle.frame = CGRectMake(0, self.bounds.size.height - 40, self.bounds.size.width, 40);

    self.upDownLoadControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
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
            [[UIColor colorWithRed: 1.0 green: 0.0 blue: 0.0 alpha: 0.8] setFill];
            [path fill];
        }
    } else {
        [super drawRect:rect];
    }

    if (self.showPlayButton) {
        CGRect frame = [self attachmentControlFrame];
        UIBezierPath* playPath = [UIBezierPath bezierPathWithOvalInRect: frame];
        [playPath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 0.43750 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.34722 * CGRectGetHeight(frame))];
        [playPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 0.43750 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.62500 * CGRectGetHeight(frame))];
        [playPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 0.63194 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.48611 * CGRectGetHeight(frame))];
        [playPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 0.43750 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.34722 * CGRectGetHeight(frame))];
        [playPath closePath];

        [[UIColor colorWithWhite: 1.0 alpha: 0.5] setStroke];
        playPath.lineWidth = 1.5;
        playPath.lineJoinStyle = kCGLineJoinRound;
        [playPath strokeWithBlendMode: kCGBlendModeNormal alpha: 1.0];
    }
}

- (CGSize) sizeThatFits:(CGSize)size {
    size.width -= 2 * kHXOGridSpacing;
    CGFloat aspect = self.image != nil ? self.image.size.width / self.image.size.height : self.imageAspect;

    size.height = size.width / aspect;
    size.width += 2 * kHXOGridSpacing;
    return size;
}

- (CGRect) attachmentControlFrame {
    CGFloat s = 9 * kHXOGridSpacing;
    CGFloat x = 0.5 * (self.bounds.size.width - s);
    CGFloat y = 0.5 * (self.bounds.size.height - s);
    return CGRectMake(x, y, s, s);
}

@end