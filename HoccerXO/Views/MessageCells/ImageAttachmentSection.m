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
#import "HXOTheme.h"
#import "HXOLayout.h"

@interface ImageAttachmentSection ()

@property (nonatomic,strong) CALayer* imageLayer;
@property (nonatomic,strong) CAShapeLayer* playButton;

@end

@implementation ImageAttachmentSection

- (void) commonInit {
    [super commonInit];

    self.subtitle.textAlignment = NSTextAlignmentCenter;
    self.subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.subtitle.frame = CGRectMake(2 * kHXOGridSpacing, self.bounds.size.height - 40, self.bounds.size.width - 4 * kHXOGridSpacing, 40);

    self.upDownLoadControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

    self.imageLayer = [CALayer layer];
    self.imageLayer.frame = self.bounds;
    self.imageLayer.mask = self.bubbleLayer;
    self.imageLayer.contentsGravity = kCAGravityResizeAspectFill;
    [self.layer insertSublayer: self.imageLayer atIndex: 0];

    self.playButton = [CAShapeLayer layer];
    self.playButton.frame = [self attachmentControlFrame];
    self.playButton.path = [self playButtonPathWithSize: self.playButton.frame.size.width].CGPath;
    self.playButton.strokeColor = [UIColor colorWithWhite: 1.0 alpha:0.5].CGColor;
    self.playButton.fillColor = NULL;
    [self.layer insertSublayer: self.playButton atIndex: 1];
}

- (void) setImage:(UIImage *)image {
    _image = image;
    self.imageLayer.contents = (id)image.CGImage;
    [self setNeedsDisplay];
}

- (void) setShowPlayButton:(BOOL)showPlayButton {
    _showPlayButton = showPlayButton;
    self.playButton.opacity = showPlayButton ? 1.0 : 0.0;
}

- (void) layoutSublayersOfLayer:(CALayer *)layer {
    [super layoutSublayersOfLayer:layer];
    if (layer == self.layer) {
        self.imageLayer.frame = self.bounds;
        self.playButton.frame = [self attachmentControlFrame];
    }
}

- (UIBezierPath*) playButtonPathWithSize: (CGFloat) size {
    CGRect frame = CGRectMake(0, 0, size, size);
    UIBezierPath* playPath = [UIBezierPath bezierPathWithOvalInRect: frame];
    [playPath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 0.43750 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.34722 * CGRectGetHeight(frame))];
    [playPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 0.43750 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.62500 * CGRectGetHeight(frame))];
    [playPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 0.63194 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.48611 * CGRectGetHeight(frame))];
    [playPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 0.43750 * CGRectGetWidth(frame), CGRectGetMinY(frame) + 0.34722 * CGRectGetHeight(frame))];
    [playPath closePath];
    return playPath;
}

- (CGRect) attachmentControlFrame {
    CGFloat s = MIN(9 * kHXOGridSpacing, MIN(self.bounds.size.height, self.bounds.size.width));
    s = MAX(s - 2 * kHXOGridSpacing, 3 * kHXOGridSpacing);
    CGFloat x = 0.5 * (self.bounds.size.width - s);
    CGFloat y = 0.5 * (self.bounds.size.height - s);
    return CGRectMake(x, y, s, s);
}

- (CGSize) sizeThatFits:(CGSize)size {
    size.width -= 2 * kHXOGridSpacing;
    //CGFloat aspect = self.image != nil ? self.image.size.width / self.image.size.height : self.imageAspect;
    CGFloat aspect = self.imageAspect != 0 ? self.imageAspect : self.image != nil ? self.image.size.width / self.image.size.height : 1.0;

    size.height = size.width / aspect;
    size.width += 2 * kHXOGridSpacing;
    return size;
}

- (void) colorSchemeDidChange {
    [super colorSchemeDidChange];
    self.imageLayer.backgroundColor = [[HXOTheme theme] messageBackgroundColorForScheme: self.cell.colorScheme].CGColor;
}

- (void) messageDirectionDidChange {
    [super messageDirectionDidChange];
    [self.layer setNeedsLayout];
}
@end
