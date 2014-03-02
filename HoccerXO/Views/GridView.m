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
            [path moveToPoint: CGPointMake(i * self.spacing + 0.5, self.bounds.origin.y + 0.5)];
            [path addLineToPoint: CGPointMake(i * self.spacing + 0.5, self.bounds.origin.y + self.bounds.size.height + 0.5)];
        }
        if (i * self.spacing < self.bounds.size.height) {
            [path moveToPoint: CGPointMake(self.bounds.origin.x + 0.5, i * self.spacing + 0.5)];
            [path addLineToPoint: CGPointMake(self.bounds.origin.x + self.bounds.size.width + 0.5, i * self.spacing + 0.5)];
        }
    }
    
    [[UIColor colorWithWhite: 0.7 alpha: 0.2] setStroke];
    [path stroke];
}

@end
