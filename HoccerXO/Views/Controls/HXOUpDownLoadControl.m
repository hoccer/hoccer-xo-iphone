//
//  HXOProgressControl.m
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOUpDownLoadControl.h"

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
}

- (void) setProgress:(CGFloat)progress {
    _progress = progress;
    [self setNeedsDisplay];
}

- (void) setProgress:(CGFloat)progress animated:(BOOL)animated {
    if (animated) {
        [UIView animateWithDuration: 0.2 animations:^{
            self.progress = progress;
        }];
    } else {
        self.progress = progress;
    }
}

- (void) setTransferDirection:(HXOTranserDirection)transferDirection {
    _transferDirection = transferDirection;
    [self setNeedsDisplay];
}

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

- (void) drawStopButton {
    CGRect buttonFrame = [self buttonFrame];
    CGFloat d = 0.25 * buttonFrame.size.width;
    UIBezierPath * path = [UIBezierPath bezierPathWithRect: CGRectInset(buttonFrame, d, d)];
    [self.tintColor setFill];
    [path fill];
}

- (void) drawArrow {
    CGRect frame = [self buttonFrame];
    CGFloat d = 0.4 * frame.size.width;
    UIBezierPath * path = [UIBezierPath bezierPath];
    CGPoint top = CGPointMake(CGRectGetMidX(frame), CGRectGetMinY(frame));
    CGPoint bottom = CGPointMake(CGRectGetMidX(frame), CGRectGetMaxY(frame));
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


    [self.tintColor setStroke];
    path.lineWidth = self.lineWidth;
    [path stroke];
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
