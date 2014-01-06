//
//  MessageSectionHeaderView.m
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "DateSectionHeaderView.h"

@implementation DateSectionHeaderView

- (id) init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}


- (void) commonInit {
    self.dateLabel = [[UILabel alloc] initWithFrame:self.bounds];
    self.dateLabel.textAlignment = NSTextAlignmentCenter;
    self.dateLabel.textColor = [UIColor colorWithWhite: 0.33 alpha: 1.0];
    self.dateLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.dateLabel.font = [UIFont boldSystemFontOfSize: 9];

    [self addSubview: self.dateLabel];

    self.backgroundView = [[UIView alloc] initWithFrame: self.bounds];
}

- (void) layoutSubviews {
    [super layoutSubviews];
}

@end
