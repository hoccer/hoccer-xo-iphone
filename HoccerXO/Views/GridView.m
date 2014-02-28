//
//  GridView.m
//  HoccerXO
//
//  Created by David Siegel on 28.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "GridView.h"

@implementation GridView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _spacing = 8.0;
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = NO;
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    [super drawRect:rect];
    UIBezierPath * path = [UIBezierPath bezierPath];
    unsigned numLines = MAX(self.bounds.size.width, self.bounds.size.height) / self.spacing;
    for (unsigned i = 0; i < numLines; ++i) {
        if (i * self.spacing < self.bounds.size.width) {
            [path moveToPoint: CGPointMake(i * self.spacing, self.bounds.origin.y)];
            [path addLineToPoint: CGPointMake(i * self.spacing, self.bounds.origin.y + self.bounds.size.height)];
        }
        if (i * self.spacing < self.bounds.size.height) {
            [path moveToPoint: CGPointMake(self.bounds.origin.x, i * self.spacing)];
            [path addLineToPoint: CGPointMake(self.bounds.origin.x + self.bounds.size.width, i * self.spacing)];
        }
    }
    
    [[UIColor colorWithWhite: 0.5 alpha: 0.5] setStroke];
    [path stroke];
}

@end
