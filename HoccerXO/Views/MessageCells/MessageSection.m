//
//  MessageSection.m
//  HoccerXO
//
//  Created by David Siegel on 11.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageSection.h"
#import "MessageCell.h"

extern CGFloat kHXOGridSpacing;


#ifdef MESSAGE_CELL_USE_LAYERS
@interface MessageSection ()


@end
#endif


@implementation MessageSection

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.backgroundColor = [UIColor clearColor];
    self.contentMode = UIViewContentModeRedraw;

#ifdef MESSAGE_CELL_USE_LAYERS
    _bubbleLayer = [CAShapeLayer layer];
    self.bubbleLayer.path = [self bubblePath].CGPath;
    [self.layer addSublayer: self.bubbleLayer];
#endif
}

#ifdef MESSAGE_CELL_USE_LAYERS
- (void) layoutSublayersOfLayer:(CALayer *)layer {
    if (layer == self.layer) {
        self.bubbleLayer.frame = self.bounds;
        self.bubbleLayer.path = [self bubblePath].CGPath;
    }
}
#endif


#ifndef MESSAGE_CELL_USE_LAYERS
- (void) drawRect:(CGRect)rect {
    [[self fillColor] setFill];
    [[self bubblePath] fill];
}
#endif


- (UIBezierPath*) bubblePath {
    CGRect frame = self.bounds;
    frame.size.width -= kHXOGridSpacing;
    if (self.position == HXOSectionPositionSingle || self.position == HXOSectionPositionLast) {
        if (self.cell.messageDirection == HXOMessageDirectionIncoming) {
            return [self leftPointingBubblePathInRect: frame];
        } else {
            frame.origin.x += kHXOGridSpacing;
            return [self rightPointingBubblePathInRect: frame];
        }
    } else {
        return [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 8, 0) cornerRadius: 12];
    }
}

- (UIColor*) fillColor {
    return [self.cell fillColor];
}

- (UIBezierPath*) rightPointingBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3.42, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 10.4, CGRectGetMaxY(frame) - 2.71) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 6.1, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 8.54, CGRectGetMaxY(frame) - 1.03)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 18, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 12.47, CGRectGetMaxY(frame) - 1.02) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 15.12, CGRectGetMaxY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 12, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 12) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 5.37, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 5.37)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 12)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 12, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 5.37) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 5.37, CGRectGetMinY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 18, CGRectGetMinY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 6, CGRectGetMinY(frame) + 12) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 11.37, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 6, CGRectGetMinY(frame) + 5.37)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 6, CGRectGetMaxY(frame) - 7.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 0.59) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 5.51, CGRectGetMaxY(frame) - 4.01) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 3.14, CGRectGetMaxY(frame) - 1.77)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3.42, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 1.07, CGRectGetMaxY(frame) - 0.21) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 2.22, CGRectGetMaxY(frame))];
    [bubblePath closePath];

    return bubblePath;
}

- (UIBezierPath*) leftPointingBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 3.42, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 10.4, CGRectGetMaxY(frame) - 2.71) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 6.1, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 8.54, CGRectGetMaxY(frame) - 1.03)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 18, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 12.47, CGRectGetMaxY(frame) - 1.02) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 15.12, CGRectGetMaxY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 12, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 12) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 5.37, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 5.37)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 12)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 12, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 5.37) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 5.37, CGRectGetMinY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 18, CGRectGetMinY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 6, CGRectGetMinY(frame) + 12) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 11.37, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 6, CGRectGetMinY(frame) + 5.37)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 6, CGRectGetMaxY(frame) - 7.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 0.59) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 5.51, CGRectGetMaxY(frame) - 4.01) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 3.14, CGRectGetMaxY(frame) - 1.77)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 3.42, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 1.07, CGRectGetMaxY(frame) - 0.21) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 2.22, CGRectGetMaxY(frame))];
    [bubblePath closePath];

    return bubblePath;
}

- (void) colorSchemeDidChange {
    self.bubbleLayer.fillColor = [self fillColor].CGColor;
}

- (void) messageDirectionDidChange {
    self.bubbleLayer.path = [self bubblePath].CGPath;
#ifndef MESSAGE_CELL_USE_LAYERS
    //[self setNeedsDisplay];
#endif
}

@end
