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
    self.minimumTrackTintColor = [UIColor lightGrayColor];
    self.maximumTrackTintColor = [UIColor lightGrayColor];
    self.thumbTintColor = self.tintColor;
}

- (CGRect) trackRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 0.0f, 0.5f * (CGRectGetHeight(bounds) - 7.0f));
}

@end
