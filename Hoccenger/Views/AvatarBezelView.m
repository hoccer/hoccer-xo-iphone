//
//  AvatarView.m
//  Hoccenger
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AvatarBezelView.h"
#import <QuartzCore/QuartzCore.h>

static const double kCornerRadius = 3.0;

@implementation AvatarBezelView

- (void) awakeFromNib {
    [super awakeFromNib];
    [self.layer setMasksToBounds: YES];
    self.layer.cornerRadius = kCornerRadius;

    /*
    self.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.layer.borderWidth = 1.0;
    */

    CALayer * layer = [CALayer layer];
    layer.contents = (id)[UIImage imageNamed: @"avatar_bezel"].CGImage;

    layer.frame = self.bounds;
    [self.layer insertSublayer: layer atIndex: 0];
}

- (void) setImage:(UIImage *)image {
    self.layer.contents = (id)image.CGImage;
    _image = image;
}

@end
