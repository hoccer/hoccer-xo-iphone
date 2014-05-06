//
//  HXOActivityIndicatorView.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOActivityIndicatorView.h"

@interface HXOActivityIndicatorView ()

@property (nonatomic, strong) CAShapeLayer * spinnerLayer;

@end

@implementation HXOActivityIndicatorView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {

    self.spinnerLayer = [CAShapeLayer layer];
    self.spinnerLayer.frame = self.bounds;
    self.spinnerLayer.path = [UIBezierPath bezierPathWithOvalInRect: self.bounds].CGPath;
    self.spinnerLayer.fillColor = NULL;
    self.spinnerLayer.strokeColor = [UIColor colorWithWhite: 1 alpha: 1].CGColor;
    [self.layer addSublayer: self.spinnerLayer];
}

- (CGSize) intrinsicContentSize {
    return self.bounds.size;
}

@end
