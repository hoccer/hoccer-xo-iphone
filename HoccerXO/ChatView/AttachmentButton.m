//
//  AttachmentButton.m
//  HoccerXO
//
//  Created by David Siegel on 05.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AttachmentButton.h"

#import "paper_clip.h"

static const CGFloat kDisabledAlpha = 0.25;

static NSString * kSpinnerAnim = @"spinnerAnim";

@interface AttachmentButton ()

@property (nonatomic, strong) CAShapeLayer * iconLayer;
@property (nonatomic, strong) CAShapeLayer * circleLayer;
@property (nonatomic, strong) CAShapeLayer * spinnerLayer;
@property (nonatomic, strong) CALayer      * previewImageLayer;

@end

@implementation AttachmentButton

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.iconLayer = [CAShapeLayer layer];
    VectorArt * paperClip = [[paper_clip alloc] init];
    self.iconLayer.bounds = paperClip.path.bounds;
    self.iconLayer.position = self.center;
    self.iconLayer.path = paperClip.path.CGPath;
    self.iconLayer.fillColor = paperClip.fillColor.CGColor;
    //self.iconLayer.strokeColor = paperClip.strokeColor.CGColor;
    [self.layer addSublayer: self.iconLayer];

    self.circleLayer = [self circleLayerInRect: CGRectInset(self.bounds, kHXOGridSpacing, kHXOGridSpacing)];
    self.circleLayer.position = self.center;
    self.circleLayer.opacity = 0;
    [self.layer addSublayer: self.circleLayer];

    self.spinnerLayer = [self circleLayerInRect: CGRectInset(self.circleLayer.bounds, 1, 1)];
    self.spinnerLayer.position = self.center;
    self.spinnerLayer.lineWidth = 2;
    self.spinnerLayer.strokeStart = 0;
    self.spinnerLayer.strokeEnd   = 0.95;
    self.spinnerLayer.opacity = 0;
    [self.layer addSublayer: self.spinnerLayer];

    self.previewImageLayer = [CALayer layer];
    self.previewImageLayer.bounds = self.circleLayer.bounds;
    self.previewImageLayer.position = self.center;
    self.previewImageLayer.contentsGravity = kCAGravityResizeAspectFill;
    self.previewImageLayer.cornerRadius = 0.5 * self.previewImageLayer.bounds.size.height;
    self.previewImageLayer.masksToBounds = YES;
    [self.layer addSublayer: self.previewImageLayer];

    self.tintColor = [UIApplication sharedApplication].delegate.window.tintColor;
    [self configure];
}

- (void) startSpinning {
    if ( ! [self.spinnerLayer animationForKey: kSpinnerAnim]) {
        CABasicAnimation * spinner = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spinner.cumulative = YES;
        spinner.toValue = @(2 * M_PI);
        spinner.duration = 1;
        spinner.repeatCount = HUGE_VALF;
        [self.spinnerLayer addAnimation: spinner forKey: kSpinnerAnim];
        [self configure];
    }
}

- (void) stopSpinning {
    [self.spinnerLayer removeAnimationForKey: kSpinnerAnim];
    [self configure];
}

- (void) setEnabled:(BOOL)enabled {
    [super setEnabled: enabled];
    [self configure];
}

- (void) setPreviewImage: (UIImage*) previewImage {
    _previewImage = previewImage;
    self.previewImageLayer.contents = (id)previewImage.CGImage;
    [self configure];
}

- (CAShapeLayer*) circleLayerInRect: (CGRect) rect {
    CAShapeLayer * circleLayer = [CAShapeLayer layer];
    circleLayer.bounds = rect;
    circleLayer.path = [UIBezierPath bezierPathWithOvalInRect: rect].CGPath;
    circleLayer.fillColor = NULL;
    return circleLayer;
}

- (void) configure {
    UIColor * strokeColor = self.isEnabled ? self.tintColor : [UIColor blackColor];
    self.iconLayer.strokeColor      = 
    self.spinnerLayer.strokeColor   =
    self.circleLayer.strokeColor    = strokeColor.CGColor;
    self.layer.opacity = self.isEnabled ? 1 : kDisabledAlpha;

    if ([self.spinnerLayer animationForKey: kSpinnerAnim]) {
        self.spinnerLayer.opacity       = 1;
        self.circleLayer.opacity        =
        self.previewImageLayer.opacity  =
        self.iconLayer.opacity          = 0;
    } else if (self.previewImage == nil && self.icon == nil) {
        self.iconLayer.opacity          = 1;
        self.spinnerLayer.opacity       =
        self.circleLayer.opacity        =
        self.previewImageLayer.opacity  = 0;
    } else if (self.previewImage) {
        self.previewImageLayer.opacity  = 1;
        self.iconLayer.opacity          =
        self.spinnerLayer.opacity       =
        self.circleLayer.opacity        = 0;
    } else if (self.icon) {
        self.iconLayer.opacity          =
        self.circleLayer.opacity        = 1;
        self.previewImageLayer.opacity  =
        self.spinnerLayer.opacity       = 0;
    }
}

@end
