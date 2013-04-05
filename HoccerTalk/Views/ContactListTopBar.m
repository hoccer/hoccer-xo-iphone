//
//  ContactListTopBar.m
//  HoccerTalk
//
//  Created by David Siegel on 04.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListTopBar.h"

#import <QuartzCore/QuartzCore.h>

@implementation ContactListTopBar

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.layer.masksToBounds = NO;
    self.layer.shadowOpacity = 0.75;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowRadius = 3;

    self.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed: @"searchbar_bg"]];
}

- (void) layoutSubviews {
    [super layoutSubviews];

    CGRect shadowRect = self.bounds;
    shadowRect.origin.x -= 2 *self.layer.shadowRadius;
    shadowRect.size.width += 4 * self.layer.shadowRadius;
    shadowRect.size.height += 5; // experimentaly found...
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect: shadowRect].CGPath;
}

@end
