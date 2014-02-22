//
//  ProfileAvatarView.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileAvatarView.h"

#import <QuartzCore/QuartzCore.h>

extern CGFloat kHXOGridSpacing;

@interface ProfileAvatarView ()

@property (nonatomic,strong) CALayer * avatarLayer;

@end

@implementation ProfileAvatarView

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        self.opaque = NO;
        self.avatarLayer = [CALayer layer];

        CGFloat size = frame.size.height - 7 * kHXOGridSpacing;
        self.avatarLayer.bounds = CGRectMake(0, 0, size, size);
        self.avatarLayer.position = self.center;

        CAShapeLayer * mask = [CAShapeLayer layer];
        mask.path = [UIBezierPath bezierPathWithOvalInRect: self.avatarLayer.bounds].CGPath;
        self.avatarLayer.mask = mask;

        [self.layer addSublayer: self.avatarLayer];
    }
    return self;
}

- (void) setImage:(UIImage *)image {
    _image = image;
    self.avatarLayer.contents = (id)image.CGImage;
    [self setNeedsDisplay];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    self.avatarLayer.position = self.center;
}

@end
