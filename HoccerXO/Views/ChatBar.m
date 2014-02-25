//
//  ChatBar.m
//  HoccerXO
//
//  Created by David Siegel on 30.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatBar.h"

@implementation ChatBar

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}


- (void) commonInit {
    self.borderColor = [UIColor colorWithWhite: 0.85 alpha: 1];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect: rect];

    UIBezierPath* bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint: CGPointMake(0, 0.5)];
    [bezierPath addLineToPoint: CGPointMake(self.bounds.size.width, 0.5)];
    [self.borderColor setStroke];
    [bezierPath stroke];
}

@end
