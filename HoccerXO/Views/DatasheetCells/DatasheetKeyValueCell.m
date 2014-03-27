//
//  DatasheetKeyValueCell.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetKeyValueCell.h"

extern const CGFloat kHXOGridSpacing;

@implementation DatasheetKeyValueCell

- (void) commonInit {
    [super commonInit];

    _valueView = [[UILabel alloc] init];
    self.valueView.autoresizingMask = UIViewAutoresizingNone;
    self.valueView.translatesAutoresizingMaskIntoConstraints = NO;
    self.valueView.font = self.titleLabel.font;
    //self.valueView.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: self.valueView];
    NSDictionary * views = @{@"title": self.titleLabel, @"value": self.valueView};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[title(<=30@750)]-%f-[value]-%f-|", 2 * kHXOGridSpacing, kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.valueView attribute: NSLayoutAttributeBaseline relatedBy: NSLayoutRelationEqual toItem: self.titleLabel attribute: NSLayoutAttributeBaseline multiplier: 1.0 constant: 0.0]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.valueView attribute: NSLayoutAttributeHeight relatedBy: NSLayoutRelationEqual toItem: self.titleLabel attribute: NSLayoutAttributeHeight multiplier: 1.0 constant: 0.0]];
}

- (void) preferredContentSizeChanged:(NSNotification *)notification {
    [super preferredContentSizeChanged: notification];
    self.valueView.font = self.titleLabel.font;
}

@end
