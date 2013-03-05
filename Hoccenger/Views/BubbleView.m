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

static const double kLeftBubbleCapLeft  = 11.0;
static const double kRightBubbleCapLeft = 5.0;
static const double kBubbleCapTop   = 32.0;

@interface BubbleView ()

@property (nonatomic) BOOL pointingRight;
@property (strong, nonatomic) UIImageView * background;

@end

@implementation BubbleView

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        //self.minHeight =  0.0; //self.frame.size.height;
        self.bubbleColor = self.backgroundColor;
        self.backgroundColor = [UIColor clearColor];

    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    double left = self.message.frame.origin.x;
    double right = self.frame.size.width - (left + self.message.frame.size.width);
    double x_padding;
    if (left > right) {
//        self.pointWidth = left - right;
        x_padding = right;
        _pointingRight = NO;
    } else {
//        self.pointWidth = right - left;
        x_padding = left;
        _pointingRight = YES;
    }
    self.padding = UIEdgeInsetsMake(self.message.frame.origin.y,
                                    x_padding,
                                    self.message.frame.origin.y,
                                    x_padding);

    NSString * file = _pointingRight == YES ? @"bubble-right" : @"bubble-left";
    UIImage * bubble = [[UIImage imageNamed: file] stretchableImageWithLeftCapWidth: _pointingRight == YES ? kRightBubbleCapLeft : kLeftBubbleCapLeft topCapHeight: kBubbleCapTop];
    self.background = [[UIImageView alloc] initWithImage: bubble];
	//self.background.frame = self.frame;
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self insertSubview: self.background atIndex: 0];
}

- (CGSize) sizeThatFits:(CGSize)size {
    return CGSizeMake(self.frame.size.width, self.message.frame.size.height + self.padding.top + self.padding.bottom);
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self sizeToFit];
    self.background.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height + 5);
}

- (double) heightForText: (NSString*) text {
    return self.padding.top + [self.message calculateSize: text].height + self.padding.bottom;
}

@end
