//
//  HXOActivityIndicatorView.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOActivityIndicatorView.h"

static NSString * const kSpinnerAnim = @"spinnerAnim";

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
    self.spinnerLayer.strokeColor = [UIColor colorWithWhite: 1 alpha: 0.9].CGColor;
    self.spinnerLayer.lineWidth = 4;
    self.spinnerLayer.strokeEnd = 0.94;
    [self.layer addSublayer: self.spinnerLayer];
}

- (CGSize) intrinsicContentSize {
    return self.bounds.size;
}

- (void) startSpinning {
    if ( ! [self.spinnerLayer animationForKey: kSpinnerAnim]) {
        CABasicAnimation * spinner = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spinner.cumulative = YES;
        spinner.toValue = @(2 * M_PI);
        spinner.duration = 1;
        spinner.repeatCount = HUGE_VALF;
        [self.spinnerLayer addAnimation: spinner forKey: kSpinnerAnim];
    }
}

- (void) stopSpinning {
    [self.spinnerLayer removeAnimationForKey: kSpinnerAnim];
}

@end
