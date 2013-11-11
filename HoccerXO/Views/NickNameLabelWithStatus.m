//
//  NickNameLabelWithStatus.m
//  HoccerXO
//
//  Created by David Siegel on 29.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NickNameLabelWithStatus.h"

static const CGFloat kLEDPadding = 3.0;
static const CGFloat kLEDSize = 6.0;


@implementation NickNameLabelWithStatus

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (CGSize) sizeThatFits:(CGSize)size {
    CGFloat ledSpace = [self ledSpace];
    size.width -= ledSpace;
    CGSize labelSize = [super sizeThatFits:size];
    labelSize.width += ledSpace;
    return labelSize;
}

- (void) drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (self.isOnline) {
        CGSize labelSize = [super sizeThatFits: self.bounds.size];
        CGFloat xPosition = self.textAlignment == NSTextAlignmentCenter ? kLEDSize + kLEDPadding + labelSize.width + kLEDPadding : labelSize.width + kLEDPadding;
        CGRect ledFrame = CGRectMake(xPosition, 0.5 * (self.bounds.size.height - kLEDSize) + self.font.pointSize / 10.0, kLEDSize, kLEDSize);
        UIBezierPath * path = [UIBezierPath bezierPathWithOvalInRect: ledFrame];
        [[UIColor redColor] setFill];
        [path fill];
    }
}

- (CGFloat) ledSpace {
    CGFloat totalSize = kLEDPadding + kLEDSize;
    return self.textAlignment == NSTextAlignmentCenter ? 2 * totalSize : totalSize;
}

- (void) setIsOnline:(BOOL)isOnline {
    _isOnline = isOnline;
    [self setNeedsDisplay];
}

@end
