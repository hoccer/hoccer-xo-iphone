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
@property (nonatomic, strong) UIView *       dots;

@end

@implementation KeyStatusCell

- (void) commonInit {
    CGFloat dotSize = 1.5 * kHXOGridSpacing; // XXX
    CGFloat space   = kHXOGridSpacing;
    self.dots = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 3 * dotSize + 2 * space, dotSize)];
    self.dots.translatesAutoresizingMaskIntoConstraints = NO;
    //self.dots.backgroundColor = [UIColor orangeColor];

    CGFloat x = 0;
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
    self.dotsLayer.anchorPoint = CGPointMake(0, 0);

    [self.dots.layer addSublayer: self.dotsLayer];

    [self.contentView addSubview: self.dots];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.dots attribute: NSLayoutAttributeCenterY relatedBy: NSLayoutRelationEqual toItem: self.contentView attribute: NSLayoutAttributeCenterY multiplier: 1 constant: 0]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.dots attribute: NSLayoutAttributeHeight relatedBy: NSLayoutRelationEqual toItem: nil attribute: NSLayoutAttributeHeight multiplier: 1 constant: dotSize]];

    [super commonInit];

    //self.valueView.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1];

}

- (void) setKeyStatusColor:(UIColor *)keyStatusColor {
    _keyStatusColor = keyStatusColor;
    self.dotsLayer.fillColor = keyStatusColor.CGColor;
}

- (NSString*) cellLayoutFormatH {
    return [NSString stringWithFormat: @"H:|-%f-[title]-%f-[value(>=20)]-[dots(==%f)]-%f-|", kHXOCellPadding, kHXOGridSpacing, self.dots.bounds.size.width, kHXOGridSpacing];
}

- (NSDictionary*) cellLayoutViews {
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithDictionary: [super cellLayoutViews]];
    result[@"dots"] = self.dots;
    return result;
}

@end
