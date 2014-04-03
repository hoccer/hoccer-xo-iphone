//
//  ProfileAvatarView.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AvatarView.h"

#import <QuartzCore/QuartzCore.h>

#import "VectorArt.h"
#import "HXOUI.h"

@interface AvatarView ()

@property (nonatomic,strong) CALayer      * avatarLayer;
@property (nonatomic,strong) CAShapeLayer * defaultAvatarLayer;
@property (nonatomic,strong) CAShapeLayer * blockedSignLayer;

@end

@implementation AvatarView

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        self.opaque = NO;

        CGFloat size = MIN(frame.size.width, frame.size.height);

        self.avatarLayer = [CALayer layer];
        self.avatarLayer.backgroundColor = [HXOUI theme].defaultAvatarBackgroundColor.CGColor;
        self.avatarLayer.position = self.center;
        self.avatarLayer.bounds = CGRectMake(0, 0, size, size);
        self.avatarLayer.mask = [self maskLayer];
        [self.layer addSublayer: self.avatarLayer];

        self.defaultAvatarLayer = [CAShapeLayer layer];
        self.defaultAvatarLayer.bounds = self.avatarLayer.bounds;
        self.defaultAvatarLayer.mask = [self maskLayer];
        [self.layer addSublayer: self.defaultAvatarLayer];

        self.blockedSignLayer = [CAShapeLayer layer];
        CGFloat blockSignSize = size - 4 * kHXOGridSpacing;
        self.blockedSignLayer.bounds = CGRectMake(0, 0, blockSignSize, blockSignSize);
        [self.layer addSublayer: self.blockedSignLayer];
        self.blockedSignLayer.opacity = 0;

        [self setNeedsLayout];
    }
    return self;
}

- (CAShapeLayer*) maskLayer {
    CAShapeLayer * mask = [CAShapeLayer layer];
    mask.path = [UIBezierPath bezierPathWithOvalInRect: self.avatarLayer.bounds].CGPath;
    return mask;
}

- (void) setImage:(UIImage *)image {
    _image = image;
    self.avatarLayer.contents = (id)image.CGImage;
    self.defaultAvatarLayer.opacity = image ? 0 : 1;
    [self setNeedsDisplay];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGFloat size = MIN(self.bounds.size.width, self.bounds.size.height) - self.padding;
    CGRect bounds = CGRectMake(0, 0, size, size);
    CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    self.avatarLayer.bounds = bounds;
    self.avatarLayer.mask = [self maskLayer];
    self.avatarLayer.position = center;

    self.defaultAvatarLayer.bounds = bounds;
    self.defaultAvatarLayer.mask = [self maskLayer];
    self.defaultAvatarLayer.position = center;

    size = size - 4 * kHXOGridSpacing; // XXX
    self.blockedSignLayer.bounds = CGRectMake(0, 0, size, size);
    self.blockedSignLayer.position = center;

    // XXX there has to be a better way to do this ...
    self.defaultAvatarLayer.path = [self.defaultIcon pathScaledToSize: self.defaultAvatarLayer.bounds.size].CGPath;
    self.blockedSignLayer.path = [self.blockedSign pathScaledToSize: self.blockedSignLayer.bounds.size].CGPath;
}

- (void) setPadding:(CGFloat)padding {
    _padding = padding;
    [self setNeedsLayout];
}

- (void) setDefaultIcon:(VectorArt *)defaultIcon {
    _defaultIcon = defaultIcon;
    _defaultAvatarLayer.fillColor = defaultIcon.fillColor.CGColor;
    _defaultAvatarLayer.strokeColor = defaultIcon.strokeColor.CGColor;
    //[self setNeedsLayout];
}

- (void) setBlockedSign:(VectorArt *)blockedSign {
    _blockedSign = blockedSign;
    _blockedSignLayer.fillColor = blockedSign.fillColor.CGColor;
    _blockedSignLayer.strokeColor = blockedSign.strokeColor.CGColor;
}

- (void) setIsBlocked:(BOOL)isBlocked {
    _isBlocked = isBlocked;
    _blockedSignLayer.opacity = isBlocked ? 1 : 0;
}

@end
