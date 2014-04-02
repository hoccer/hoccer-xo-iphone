//
//  ProfileAvatarView.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileAvatarView.h"

#import <QuartzCore/QuartzCore.h>

#import "VectorArt.h"
#import "HXOUI.h"

@interface ProfileAvatarView ()

@property (nonatomic,strong) CALayer * avatarLayer;
@property (nonatomic,strong) CAShapeLayer * defaultAvatarLayer;
@property (nonatomic,strong) CAShapeLayer * blockedSignLayer;

@end

@implementation ProfileAvatarView

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        self.opaque = NO;
        self.avatarLayer = [CALayer layer];
        self.avatarLayer.backgroundColor = [HXOUI theme].defaultAvatarBackgroundColor.CGColor;

        CGFloat size = frame.size.height - 6 * kHXOGridSpacing;
        self.avatarLayer.bounds = CGRectMake(0, 0, size, size);
        self.avatarLayer.position = self.center;
        self.avatarLayer.mask = [self maskLayer];
        [self.layer addSublayer: self.avatarLayer];

        self.defaultAvatarLayer = [CAShapeLayer layer];
        self.defaultAvatarLayer.bounds = self.avatarLayer.bounds;
        self.defaultAvatarLayer.mask = [self maskLayer];
        [self.layer addSublayer: self.defaultAvatarLayer];

        self.blockedSignLayer = [CAShapeLayer layer];
        CGFloat blockSignSize = size - 3 * kHXOGridSpacing;
        self.blockedSignLayer.bounds = CGRectMake(0, 0, blockSignSize, blockSignSize);
        [self.layer addSublayer: self.blockedSignLayer];
        self.blockedSignLayer.opacity = 0;
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
    self.avatarLayer.position = self.center;
    self.defaultAvatarLayer.position = self.center;
    self.blockedSignLayer.position = self.center;
}

- (void) setDefaultIcon:(VectorArt *)defaultIcon {
    _defaultIcon = defaultIcon;
    _defaultAvatarLayer.path = [defaultIcon pathScaledToSize: _defaultAvatarLayer.bounds.size].CGPath;
    _defaultAvatarLayer.fillColor = defaultIcon.fillColor.CGColor;
    _defaultAvatarLayer.strokeColor = defaultIcon.strokeColor.CGColor;
}

- (void) setBlockedSign:(VectorArt *)blockedSign {
    _blockedSign = blockedSign;
    _blockedSignLayer.path = [blockedSign pathScaledToSize: _blockedSignLayer.bounds.size].CGPath;
    _blockedSignLayer.fillColor = blockedSign.fillColor.CGColor;
    _blockedSignLayer.strokeColor = blockedSign.strokeColor.CGColor;
}

- (void) setIsBlocked:(BOOL)isBlocked {
    _isBlocked = isBlocked;
    _blockedSignLayer.opacity = isBlocked ? 1 : 0;
}

@end
