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

extern CGFloat kHXOGridSpacing;

@interface ProfileAvatarView ()

@property (nonatomic,strong) CALayer * avatarLayer;
@property (nonatomic,strong) CAShapeLayer * defaultAvatarLayer;

@end

@implementation ProfileAvatarView

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        self.opaque = NO;
        self.avatarLayer = [CALayer layer];
        self.avatarLayer.backgroundColor = [HXOTheme theme].defaultAvatarBackgroundColor.CGColor;

        CGFloat size = frame.size.height - 7 * kHXOGridSpacing;
        self.avatarLayer.bounds = CGRectMake(0, 0, size, size);
        self.avatarLayer.position = self.center;

        CAShapeLayer * mask = [CAShapeLayer layer];
        mask.path = [UIBezierPath bezierPathWithOvalInRect: self.avatarLayer.bounds].CGPath;
        self.avatarLayer.mask = mask;

        [self.layer addSublayer: self.avatarLayer];

        self.defaultAvatarLayer = [CAShapeLayer layer];
        _defaultAvatarLayer.bounds = self.avatarLayer.bounds;
        mask = [CAShapeLayer layer];
        mask.path = [UIBezierPath bezierPathWithOvalInRect: self.avatarLayer.bounds].CGPath;
        _defaultAvatarLayer.mask = mask;

        [self.layer addSublayer: self.defaultAvatarLayer];
    }
    return self;
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
}

- (void) setDefaultIcon:(VectorArt *)defaultIcon {
    _defaultIcon = defaultIcon;

    _defaultAvatarLayer.path = [defaultIcon pathScaledToSize: _defaultAvatarLayer.bounds.size].CGPath;
    _defaultAvatarLayer.fillColor = defaultIcon.fillColor.CGColor;
    _defaultAvatarLayer.strokeColor = defaultIcon.strokeColor.CGColor;
    //_defaultAvatarLayer.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 0.2].CGColor;
}
@end
