//
//  SeekSlider.m
//  HoccerXO
//
//  Created by Guido Lorenz on 13.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SeekSlider.h"

#import "UIImage+Tint.h"

@implementation SeekSlider

- (CGRect) trackRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 0.0f, 0.5f * (CGRectGetHeight(bounds) - 7.0f));
}

- (void) tintColorDidChange {
    UIImage *trackImage = [[[UIImage imageNamed:@"slider-track"] tintWithColor:[UIColor colorWithWhite:1.0 alpha:0.6]] resizableImageWithCapInsets:UIEdgeInsetsZero];
    [self setMinimumTrackImage:trackImage forState:UIControlStateNormal];
    [self setMaximumTrackImage:trackImage forState:UIControlStateNormal];
    
    UIImage *thumbImage = [[UIImage imageNamed:@"slider-thumb"] tintWithColor:self.tintColor];
    [self setThumbImage:thumbImage forState:UIControlStateNormal];
}

@end
