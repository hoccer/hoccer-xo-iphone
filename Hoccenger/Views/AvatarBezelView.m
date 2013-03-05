//
//  AvatarView.m
//  Hoccenger
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AvatarBezelView.h"
#import <QuartzCore/QuartzCore.h>
#import "CornerRadius.h"

@implementation AvatarBezelView

- (void) awakeFromNib {
    [super awakeFromNib];
    [self.layer setMasksToBounds: YES];
    self.layer.cornerRadius = kCornerRadius;

    [self.layer setBorderColor: [[UIColor darkGrayColor] CGColor]];
    [self.layer setBorderWidth: 1.0];
}

- (UIImage*) image {
    return self.imageView.image;
}

- (void) setImage:(UIImage *)image {
    self.imageView.image = image;
}

@end
