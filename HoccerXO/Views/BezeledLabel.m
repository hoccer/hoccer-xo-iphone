//
//  BezeledLabel.m
//  HoccerXO
//
//  Created by David Siegel on 28.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BezeledLabel.h"

@implementation BezeledLabel

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textAlignment = NSTextAlignmentCenter;
    self.bezelColor = self.backgroundColor;
    self.backgroundColor = [UIColor clearColor];
    self.bezelBorder = 1;

}

- (CGSize) sizeThatFits:(CGSize)size {
    CGSize labelSize = [super sizeThatFits: size];
    CGFloat radius = [self radiusForLabelHeight: labelSize.height];
    labelSize.width = labelSize.width > labelSize.height ? labelSize.width + radius : 2.0 * radius;
    labelSize.height = 2.0 * radius;
    return labelSize;
}

- (CGFloat) radiusForLabelHeight: (CGFloat) height {
    return self.bezelBorder + 0.5 * height;
}

- (void) drawRect:(CGRect)rect {
    UIBezierPath * path = self.bounds.size.width > self.bounds.size.height ? [UIBezierPath bezierPathWithRoundedRect: self.bounds cornerRadius: self.bounds.size.height / 2.0] : [UIBezierPath bezierPathWithOvalInRect: self.bounds];
    [self.bezelColor setFill];
    [path fill];
    [super drawRect: rect];
}

@end
