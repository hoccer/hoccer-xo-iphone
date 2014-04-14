//
//  KeyStatusCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "KeyStatusCell.h"
#import "HXOUI.h"


@interface KeyStatusCell ()

@property (nonatomic, strong) CAShapeLayer * dotsLayer;

@end

@implementation KeyStatusCell

- (void) commonInit {
    [super commonInit];

    CGFloat x = 0;
    CGFloat dotSize = 1.5 * kHXOGridSpacing; // XXX
    CGFloat space   = kHXOGridSpacing;
    UIBezierPath * dots = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(x, 0, dotSize, dotSize)];
    x += dotSize + space;
    [dots appendPath: [UIBezierPath bezierPathWithOvalInRect: CGRectMake( x, 0, dotSize, dotSize)]];
    x += dotSize + space;
    [dots appendPath: [UIBezierPath bezierPathWithOvalInRect: CGRectMake( x, 0, dotSize, dotSize)]];

    self.dotsLayer = [CAShapeLayer layer];
    self.dotsLayer.contentsGravity = kCAGravityResizeAspect;
    self.dotsLayer.bounds = CGRectMake(0, 0, 3 * dotSize + 2 * space, dotSize);
    self.dotsLayer.path = dots.CGPath;
    self.dotsLayer.fillColor = self.keyStatusColor.CGColor;
    self.dotsLayer.anchorPoint = CGPointMake(1, 0.5);

    [self.contentView.layer addSublayer: self.dotsLayer];
}

- (void) setKeyStatusColor:(UIColor *)keyStatusColor {
    _keyStatusColor = keyStatusColor;
    self.dotsLayer.fillColor = keyStatusColor.CGColor;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    self.dotsLayer.position = CGPointMake(self.contentView.bounds.size.width - kHXOCellPadding, self.contentView.bounds.size.height / 2);
}

@end
