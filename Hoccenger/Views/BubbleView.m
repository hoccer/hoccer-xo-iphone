//
//  BubbleView.m
//  Hoccenger
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleView.h"

#import <QuartzCore/QuartzCore.h>

#import "AutoheightLabel.h"
#import "CornerRadius.h"

@interface BubbleView ()

@property (nonatomic) BOOL pointingRight;
@property (nonatomic) double pointCenter;
@property (strong, nonatomic) UIBezierPath * bubblePath;
@property (strong, nonatomic) CAShapeLayer * shape;
@property (strong, nonatomic) CAShapeLayer * glow;
@property (strong, nonatomic) CAGradientLayer * gradient;

@end

@implementation BubbleView

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        self.minHeight = self.frame.size.height;
        _pointCenter = 0.5 * self.frame.size.height;
        self.bubbleColor = self.backgroundColor;
        self.backgroundColor = [UIColor clearColor];

        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.3f;
        self.layer.shadowOffset = CGSizeMake(2.0f, 2.0f);
        self.layer.shadowRadius = 3.0f;
        self.layer.masksToBounds = NO;

        self.shape = [CAShapeLayer layer];
        self.shape.fillColor = self.bubbleColor.CGColor;
        self.shape.strokeColor = [UIColor colorWithWhite: 0.0 alpha: 0.5].CGColor;
        [self.layer insertSublayer: self.shape atIndex: 0];

        self.gradient = [self gradientLayer];
        //[self.layer insertSublayer: self.gradient atIndex: 1];

        self.glow = [CAShapeLayer layer];
        self.glow.fillColor = [UIColor clearColor].CGColor;
        self.glow.strokeColor = [UIColor colorWithWhite: 1.0 alpha: 0.5].CGColor;
        [self.layer insertSublayer: self.glow atIndex: 2];

    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    double left = self.message.frame.origin.x;
    double right = self.frame.size.width - (left + self.message.frame.size.width);
    double x_padding;
    if (left > right) {
        self.pointWidth = left - right;
        x_padding = right;
        _pointingRight = NO;
    } else {
        self.pointWidth = right - left;
        x_padding = left;
        _pointingRight = YES;
    }
    self.padding = UIEdgeInsetsMake(self.message.frame.origin.y,
                                    x_padding,
                                    self.message.frame.origin.y,
                                    x_padding);
}

- (CGSize) sizeThatFits:(CGSize)size {
    return CGSizeMake(self.frame.size.width, MAX(self.message.frame.size.height + self.padding.top + self.padding.bottom, self.minHeight));
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self sizeToFit];


    CGRect rect = CGRectMake(self.bounds.origin.x + 0.5 + (_pointingRight ? 0 : self.pointWidth),
                             self.bounds.origin.y + 0.5,
                             self.bounds.size.width - self.pointWidth - 1, self.bounds.size.height - 1);
    UIBezierPath* path = [self createBubblePathInRect: rect]; // XXX?
    _bubblePath = path;
    self.layer.shadowPath = path.CGPath;
    self.shape.frame = self.bounds;
    self.shape.path = path.CGPath;

    self.gradient.frame = self.bounds;
    //[self.gradient setMask: self.shape];

    rect = CGRectMake(self.bounds.origin.x + 1.5 + (_pointingRight ? 0 : self.pointWidth),
                      self.bounds.origin.y + 1.5,
                      self.bounds.size.width - self.pointWidth - 3, self.bounds.size.height - 3);
    path = [self createBubblePathInRect: rect];
    self.glow.path = path.CGPath;
    self.glow.frame = self.bounds;
}

- (double) heightForText: (NSString*) text {
    return self.padding.top + [self.message calculateSize: text].height + self.padding.bottom;
}

- (UIBezierPath*) createBubblePathInRect: (CGRect) rect {

    UIBezierPath * path = [[UIBezierPath alloc] init];
    [path moveToPoint: CGPointMake(rect.origin.x, rect.origin.y + kCornerRadius)];

    if (_pointingRight == NO) {
        // TODO: add arc
        [path addLineToPoint: CGPointMake(rect.origin.x, _pointCenter - _pointWidth)];
        [path addLineToPoint: CGPointMake(rect.origin.x - self.pointWidth, _pointCenter)];
        [path addLineToPoint: CGPointMake(rect.origin.x, _pointCenter + _pointWidth)];
        // TODO: add arc
    }

    [path addLineToPoint: CGPointMake(rect.origin.x, rect.origin.y + rect.size.height - kCornerRadius)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + kCornerRadius, rect.origin.y + rect.size.height - kCornerRadius)
                    radius: kCornerRadius startAngle: M_PI endAngle: M_PI / 2 clockwise: NO];
    [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width - kCornerRadius, rect.origin.y + rect.size.height)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + rect.size.width - kCornerRadius, rect.origin.y + rect.size.height - kCornerRadius)
                    radius: kCornerRadius startAngle: M_PI / 2 endAngle: 0.0 clockwise: NO];

    if (_pointingRight == YES) {
        // TODO: add arc
        [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, _pointCenter + _pointWidth)];
        [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width + _pointWidth, _pointCenter)];
        [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, _pointCenter - _pointWidth)];
        // TODO: add arc
    }

    [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + kCornerRadius)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + rect.size.width - kCornerRadius, rect.origin.y + kCornerRadius)
                    radius: kCornerRadius startAngle: 0.0 endAngle: -M_PI / 2 clockwise: NO];
    [path addLineToPoint: CGPointMake(rect.origin.x + kCornerRadius, rect.origin.y)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + kCornerRadius, rect.origin.y + kCornerRadius)
                    radius: kCornerRadius startAngle: -M_PI / 2 endAngle: M_PI clockwise: NO];
    return path;
}

- (CAGradientLayer*) gradientLayer {
    UIColor *colorOne   = [UIColor colorWithWhite: 0.0 alpha: 0.1];
    UIColor *colorTwo   = [UIColor clearColor];
    UIColor *colorThree = [UIColor clearColor];
    UIColor *colorFour  = [UIColor colorWithWhite: 0.0 alpha: 0.1];

    NSArray *colors =  @[(id)colorOne.CGColor, (id)colorTwo.CGColor, (id)colorThree.CGColor, (id)colorFour.CGColor];

    NSNumber *stopOne   = [NSNumber numberWithFloat:0.0];
    NSNumber *stopTwo   = [NSNumber numberWithFloat:0.15];
    NSNumber *stopThree = [NSNumber numberWithFloat:0.85];
    NSNumber *stopFour  = [NSNumber numberWithFloat:1.0];

    NSArray *locations = [NSArray arrayWithObjects:stopOne, stopTwo, stopThree, stopFour, nil];
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.colors = colors;
    layer.locations = locations;

    return layer;
}

@end
