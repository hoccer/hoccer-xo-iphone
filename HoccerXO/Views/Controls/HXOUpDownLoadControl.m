//
//  HXOProgressControl.m
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOUpDownLoadControl.h"


static const CGFloat kHXOSpinningEnd = 0.95;

NSString * kSpinnerAnim = @"spinner";

@interface HXOUpDownLoadControl ()

@property (nonatomic,strong) CAShapeLayer * iconLayer;
@property (nonatomic,strong) CAShapeLayer * circleLayer;
@property (nonatomic,strong) CAShapeLayer * progressLayer;

@end

@implementation HXOUpDownLoadControl

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.lineWidth = 1.0;

    CGPoint anchor = CGPointMake(0.5, 0.5);
    CGPoint center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);

    self.circleLayer = [CAShapeLayer layer];
    self.circleLayer.bounds = self.bounds;
    self.circleLayer.path = [UIBezierPath bezierPathWithOvalInRect:self.circleLayer.bounds].CGPath;
    self.circleLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.circleLayer.fillColor = NULL;
    self.circleLayer.anchorPoint = anchor;
    self.circleLayer.position = center;
    [self.layer addSublayer: self.circleLayer];


    self.iconLayer = [CAShapeLayer layer];
    self.iconLayer.anchorPoint = anchor;
    self.iconLayer.bounds = [self buttonFrame];
    self.iconLayer.position = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    [self.layer addSublayer: self.iconLayer];

    self.progressLayer = [CAShapeLayer layer];
    self.progressLayer.bounds = self.bounds;
    self.progressLayer.path = [UIBezierPath bezierPathWithArcCenter: center radius: center.x startAngle: -0.5 * M_PI endAngle: 1.5 * M_PI clockwise:YES].CGPath;
    self.progressLayer.strokeColor = self.tintColor.CGColor;
    self.progressLayer.fillColor = NULL;
    self.progressLayer.anchorPoint = anchor;
    self.progressLayer.position = center;
    self.progressLayer.strokeEnd = kHXOSpinningEnd;
    [self.layer addSublayer: self.progressLayer];
}

- (void) setProgress:(CGFloat)progress {
    _progress = progress;
    [self.progressLayer removeAnimationForKey: kSpinnerAnim];
    self.progressLayer.opacity = 1.0;
    self.progressLayer.strokeEnd = progress;
//    [self.progressLayer setValue: @(0) forKeyPath:@"transform.rotation.z"];
}

- (void) setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self updateIcon];
}

- (void) updateIcon {
    if (self.selected) {
        CGRect buttonFrame = [self.iconLayer bounds];
        CGFloat d = 0.25 * buttonFrame.size.width;
        self.iconLayer.path = [UIBezierPath bezierPathWithRect: CGRectInset(buttonFrame, d, d)].CGPath;
        self.iconLayer.fillColor = self.tintColor.CGColor;
        self.iconLayer.strokeColor = NULL;
    } else {
        self.iconLayer.path = [self arrowPath: self.iconLayer.bounds].CGPath;
        self.iconLayer.fillColor = NULL;
        self.iconLayer.strokeColor = self.tintColor.CGColor;
    }

}

- (void) setTransferDirection:(HXOTranserDirection)transferDirection {
    _transferDirection = transferDirection;
    [self updateIcon];
}

- (void) startSpinning {
    if ( ! [self.progressLayer animationForKey: kSpinnerAnim]) {
        CABasicAnimation * spinner = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        spinner.cumulative = YES;
        spinner.toValue = @(2 * M_PI);
        spinner.duration = 2.0;
        spinner.repeatCount = HUGE_VALF;
        [self.progressLayer addAnimation: spinner forKey: kSpinnerAnim];
    }
}

/*
- (void) drawRect:(CGRect)rect {
    UIBezierPath * circle = [UIBezierPath bezierPathWithOvalInRect: [self circleFrame]];
    circle.lineWidth = self.lineWidth;
    //[self.tintColor setStroke];
    [[UIColor whiteColor] setStroke];
    [circle stroke];

    CGPoint center = CGPointMake(CGRectGetMidX(circle.bounds), CGRectGetMidY(circle.bounds));
    CGFloat radius = 0.5 * CGRectGetWidth(circle.bounds);
    CGFloat endAngle = -0.5 * M_PI + self.progress * 2 * M_PI;
    circle = [UIBezierPath bezierPathWithArcCenter: center radius: radius startAngle: -0.5 * M_PI endAngle: endAngle clockwise: YES];
    [self.tintColor setStroke];
    [circle stroke];

    if (self.selected) {
        [self drawStopButton];
    } else {
        [self drawArrow];
    }
}
*/
- (void) drawStopButton {
    CGRect buttonFrame = [self buttonFrame];
    CGFloat d = 0.25 * buttonFrame.size.width;
    UIBezierPath * path = [UIBezierPath bezierPathWithRect: CGRectInset(buttonFrame, d, d)];
    [self.tintColor setFill];
    [path fill];
}

- (void) drawArrow {
    UIBezierPath * path = [self arrowPath: [self buttonFrame]];
    [self.tintColor setStroke];
    path.lineWidth = self.lineWidth;
    [path stroke];
}

- (UIBezierPath*) arrowPath: (CGRect) frame {
    CGFloat d = 0.4 * frame.size.width;
    CGPoint top = CGPointMake(CGRectGetMidX(frame), CGRectGetMinY(frame));
    CGPoint bottom = CGPointMake(CGRectGetMidX(frame), CGRectGetMaxY(frame));
    UIBezierPath * path = [UIBezierPath bezierPath];
    [path moveToPoint: top];
    [path addLineToPoint: bottom];
    if (self.transferDirection == HXOTranserDirectionReceiving) {
        [path moveToPoint: CGPointMake(bottom.x - d, bottom.y - d)];
        [path addLineToPoint: bottom];
        [path addLineToPoint: CGPointMake(bottom.x + d, bottom.y - d)];
    } else {
        [path moveToPoint: CGPointMake(top.x - d, top.y + d)];
        [path addLineToPoint: top];
        [path addLineToPoint: CGPointMake(top.x + d, top.y + d)];
    }
    return path;
}

- (CGRect) buttonFrame {
    CGRect circleFrame = [self circleFrame];
    CGFloat delta = 0.25 * circleFrame.size.width;
    return CGRectInset(circleFrame, delta, delta);
}

- (CGRect) circleFrame {
    CGFloat sideLength = MIN(self.bounds.size.height, self.bounds.size.width) - self.lineWidth;
    CGFloat x = 0.5 * (self.bounds.size.width - sideLength);
    CGFloat y = 0.5 * (self.bounds.size.height - sideLength);
    return CGRectMake(x, y, sideLength, sideLength);
}

@end
