//
//  AvatarView.m
//  HoccerTalk
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AvatarBezelView.h"
#import <QuartzCore/QuartzCore.h>

@interface AvatarBezelView ()

@property (nonatomic,strong) CALayer* imageLayer;
@property (nonatomic,strong) CAShapeLayer* insetLayer;
@property (nonatomic,strong) CAShapeLayer* innerShadowLayer;
@property (nonatomic,strong) CAShapeLayer* bezelLayer;

@end

@implementation AvatarBezelView

- (id) init {
    self = [super init];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.cornerRadius = 4;

    self.imageLayer = [CALayer layer];
    self.imageLayer.cornerRadius = self.cornerRadius;
    [self.layer insertSublayer: self.imageLayer atIndex: 0];

    self.insetLayer = [CAShapeLayer layer];
    self.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.8];
    self.insetLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer insertSublayer: self.insetLayer atIndex: 1];

    self.innerShadowLayer = [CAShapeLayer layer];
    self.innerShadowColor = [UIColor colorWithWhite: 0.0 alpha: 0.25];
    self.innerShadowLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer insertSublayer: self.innerShadowLayer atIndex: 2];

    self.bezelLayer = [CAShapeLayer layer];
    self.bezelColor = [UIColor colorWithWhite: 0.2 alpha: 1.0];
    self.bezelLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer insertSublayer: self.bezelLayer atIndex: 3];

    self.layer.backgroundColor = [UIColor clearColor].CGColor;
    self.layer.masksToBounds = YES;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2) {
        self.layer.rasterizationScale=2.0;
    }
    self.layer.shouldRasterize = YES;
}

- (void) layoutSubviews {
    [super layoutSubviews];

    self.imageLayer.frame = CGRectInset(self.bounds, 1, 1);

    CGRect insetRect = CGRectInset(self.bounds, 0.5, 0.5);
    self.insetLayer.path = [self roundedRectTopSection: insetRect].CGPath;
    self.insetLayer.frame = self.bounds;

    CGRect shadowRect = CGRectMake(self.bounds.origin.x + 0.5, self.bounds.origin.y + 1.5, self.bounds.size.width - 1, self.bounds.size.height - 1);
    self.innerShadowLayer.path = [self roundedRect: shadowRect].CGPath;
    self.innerShadowLayer.frame = self.bounds;

    CGRect bezelRect = CGRectMake(self.bounds.origin.x + 0.5, self.bounds.origin.y + 0.5, self.bounds.size.width - 1, self.bounds.size.height - 2);
    self.bezelLayer.path = [self roundedRect: bezelRect].CGPath;
    self.bezelLayer.frame = self.bounds;

    CAShapeLayer * imageMask = [CAShapeLayer layer];
    imageMask.path = self.bezelLayer.path;
    imageMask.frame = self.bounds;
    imageMask.strokeColor = imageMask.fillColor = [UIColor whiteColor].CGColor;
    self.imageLayer.mask = imageMask;
    //self.imageLayer.masksToBounds = YES;


    CAShapeLayer * mask = [CAShapeLayer layer];
    mask.path = [self roundedRect: insetRect].CGPath;
    mask.frame = self.bounds;
    mask.strokeColor = mask.fillColor = [UIColor whiteColor].CGColor;
    self.layer.mask = mask;
}

- (void) setImage:(UIImage *)image {
    self.imageLayer.contents = (id)image.CGImage;
    _image = image;

    // TODO: handle image aspect
/*
    CGFloat imageAspect = image.size.width / image.size.height;
    CGFloat frameAspect = self.bounds.size.width / self.bounds.size.height;

    NSLog(@"w: %f h: %f", image.size.width, image.size.height);

    if (imageAspect > frameAspect) {
        NSLog(@"fit height");
    } else {
        NSLog(@"fit width");
    }
 */
}

- (UIBezierPath*) roundedRect: (CGRect) rect {
    UIBezierPath * path = [UIBezierPath bezierPath];
    [path moveToPoint: CGPointMake(rect.origin.x, rect.origin.y + self.cornerRadius)];
    [path addLineToPoint: CGPointMake(rect.origin.x, rect.origin.y + rect.size.height - self.cornerRadius)];

    [self addRoundedRectTopSection: rect toPath: path];

    [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + self.cornerRadius)];

    [self addRoundedRectBottomSection: rect toPath: path];

    return path;
}

- (UIBezierPath*) roundedRectTopSection: (CGRect) rect {
    UIBezierPath * path = [UIBezierPath bezierPath];
    [path moveToPoint: CGPointMake(rect.origin.x, rect.origin.y + rect.size.height - self.cornerRadius)];
    [self addRoundedRectTopSection: rect toPath: path];
    return path;
}

- (void) addRoundedRectTopSection: (CGRect) rect toPath: (UIBezierPath*) path {
    [path addArcWithCenter: CGPointMake(rect.origin.x + self.cornerRadius, rect.origin.y + rect.size.height - self.cornerRadius)
                    radius: self.cornerRadius startAngle: M_PI endAngle: M_PI / 2 clockwise: NO];
    [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width - self.cornerRadius, rect.origin.y + rect.size.height)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + rect.size.width - self.cornerRadius, rect.origin.y + rect.size.height - self.cornerRadius)
                    radius: self.cornerRadius startAngle: M_PI / 2 endAngle: 0.0 clockwise: NO];
}

- (UIBezierPath*) roundedRectBottomSection: (CGRect) rect {
    UIBezierPath * path = [UIBezierPath bezierPath];
    [path moveToPoint: CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + self.cornerRadius)];
    [self addRoundedRectBottomSection: rect toPath: path];
    return path;
}

- (void) addRoundedRectBottomSection: (CGRect) rect toPath: (UIBezierPath*) path {
    [path addArcWithCenter: CGPointMake(rect.origin.x + rect.size.width - self.cornerRadius, rect.origin.y + self.cornerRadius)
                    radius: self.cornerRadius startAngle: 0.0 endAngle: -M_PI / 2 clockwise: NO];
    [path addLineToPoint: CGPointMake(rect.origin.x + self.cornerRadius, rect.origin.y)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + self.cornerRadius, rect.origin.y + self.cornerRadius)
                    radius: self.cornerRadius startAngle: -M_PI / 2 endAngle: M_PI clockwise: NO];
}

- (void) setBezelColor:(UIColor *)bezelColor {
    _bezelColor = bezelColor;
    self.bezelLayer.strokeColor = bezelColor.CGColor;
    [self setNeedsDisplay];
}

- (void) setInsetColor:(UIColor *)insetColor {
    _insetColor = insetColor;
    self.insetLayer.strokeColor = insetColor.CGColor;
    [self setNeedsDisplay];
}

- (void) setInnerShadowColor:(UIColor *)innerShadowColor {
    _innerShadowColor = innerShadowColor;
    self.innerShadowLayer.strokeColor = innerShadowColor.CGColor;
    [self setNeedsDisplay];
}

- (void) setCornerRadius:(double)cornerRadius {
    _cornerRadius = cornerRadius;
    [self setNeedsDisplay];
}

@end
