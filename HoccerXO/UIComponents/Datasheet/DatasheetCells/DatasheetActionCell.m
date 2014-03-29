//
//  DatasheetActionCell.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetActionCell.h"

#import "HXOTheme.h"

extern const CGFloat kHXOGridSpacing;

@implementation DatasheetActionCell

- (void) commonInit {
    [super commonInit];

    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    NSDictionary * views = @{@"label": self.titleLabel};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[label]-%f-|", kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
}

@end
