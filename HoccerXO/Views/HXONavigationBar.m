//
//  CustomNavigationBar.m
//  HoccerXO
//
//  Created by David Siegel on 02.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXONavigationBar.h"

#import <QuartzCore/QuartzCore.h>

#import "HXONavigationItem.h"

static const CGFloat kButtonWidth = 49;
static const CGFloat kButtonColumnWidth = 63;
static const CGFloat kButtonXOffset = 0.5 * (kButtonColumnWidth - kButtonWidth);


@implementation HXONavigationBar

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.layer.masksToBounds = NO;
    self.layer.shadowOpacity = 1.0;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowRadius = 3;
    _mask = [CAShapeLayer layer];
    self.layer.mask = _mask;
}

- (void) layoutSubviews {
    [super layoutSubviews];

    CGRect shadowRect = self.bounds;
    shadowRect.origin.x -= 2 *self.layer.shadowRadius;
    shadowRect.size.width += 4 * self.layer.shadowRadius;
    shadowRect.size.height += 5; // experimentaly found...
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect: shadowRect].CGPath;

    CGRect maskRect = self.bounds;
    maskRect.size.height += 5 + 2 * self.layer.shadowRadius;
    _mask.path = [UIBezierPath bezierPathWithRect: maskRect].CGPath;

    CGFloat screenWidth = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) ? [UIScreen mainScreen].applicationFrame.size.width : [UIScreen mainScreen].applicationFrame.size.height;

    BOOL flexibleLeftButton = [self.topItem isKindOfClass: [HXONavigationItem class]] ? ((HXONavigationItem*)self.topItem).flexibleLeftButton : NO;
    BOOL flexibleRightButton = [self.topItem isKindOfClass: [HXONavigationItem class]] ? ((HXONavigationItem*)self.topItem).flexibleRightButton : NO;

    for (UIView * subview in self.subviews) {
        if ([NSStringFromClass([subview class]) isEqualToString: @"UINavigationButton"]) {
            CGRect frame = subview.frame;
            if (frame.origin.x > 0.5 * screenWidth ) {
                if ( ! flexibleRightButton) {
                    frame.size.width = kButtonWidth;
                }
                frame.origin.x = screenWidth - kButtonXOffset - frame.size.width;
            } else {
                if ( ! flexibleLeftButton) {
                    frame.size.width = kButtonWidth;
                }
                frame.origin.x = kButtonXOffset;
            }
            subview.frame = frame;
        }
    }
}

@end
