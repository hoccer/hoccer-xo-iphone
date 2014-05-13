//
//  SeekSlider.m
//  HoccerXO
//
//  Created by Guido Lorenz on 13.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SeekSlider.h"

@implementation SeekSlider

- (void) awakeFromNib {
    UIImage *trackImage = [[UIImage imageNamed:@"slider-track"] resizableImageWithCapInsets:UIEdgeInsetsZero];
    [self setMinimumTrackImage:trackImage forState:UIControlStateNormal];
    [self setMaximumTrackImage:trackImage forState:UIControlStateNormal];

    UIImage *thumbImage = [UIImage imageNamed:@"slider-thumb"];
    [self setThumbImage:thumbImage forState:UIControlStateNormal];
}

- (CGRect) trackRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 0.0f, 0.5f * (CGRectGetHeight(bounds) - 7.0f));
}

@end
