//
//  DatasheetActionCell.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetActionCell.h"

#import "HXOUI.h"
#import "HXOUI.h"

@implementation DatasheetActionCell

- (void) commonInit {
    [super commonInit];

    //self.titleLabel.textColor = [UIColor blackColor];
    //self.titleLabel.textAlignment = NSTextAlignmentCenter;

    self.busyIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleGray];
    self.busyIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.busyIndicator.autoresizingMask = UIViewAutoresizingNone;
    [self.contentView addSubview: self.busyIndicator];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.busyIndicator
                                                                  attribute: NSLayoutAttributeCenterY
                                                                  relatedBy: NSLayoutRelationEqual
                                                                     toItem: self.contentView
                                                                  attribute: NSLayoutAttributeCenterY
                                                                 multiplier: 1 constant: 0]];
    
    NSDictionary * views = @{@"label": self.titleLabel, @"spinner": self.busyIndicator};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[label]-%f-[spinner]-%f-|", kHXOCellPadding, kHXOGridSpacing, kHXOCellPadding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
}

@end
