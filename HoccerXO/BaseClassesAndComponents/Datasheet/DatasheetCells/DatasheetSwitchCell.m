//
//  DatasheetSwitchCell.m
//  HoccerXO
//
//  Created by David Siegel on 27.01.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "DatasheetSwitchCell.h"
#import "HXOUI.h"

@implementation DatasheetSwitchCell

- (void) commonInit {
    [super commonInit];

    _valueView = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.valueView.autoresizingMask = UIViewAutoresizingNone;
    self.valueView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.valueView addTarget: self action: @selector(valueDidChange:) forControlEvents: UIControlEventValueChanged];
    [self.contentView addSubview: self.valueView];
    NSDictionary * views = @{@"title": self.titleLabel, @"value": self.valueView};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[title]-(>=%f)-[value]-%f-|", 2 * kHXOGridSpacing, kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.valueView attribute: NSLayoutAttributeCenterY relatedBy: NSLayoutRelationEqual toItem: self.contentView attribute: NSLayoutAttributeCenterY multiplier: 1.0 constant: 0.0]];

}

- (void) valueDidChange: (id) sender {
    if ([self.delegate respondsToSelector: @selector(datasheetCell:didChangeValueForView:)]) {
        [self.delegate datasheetCell: self didChangeValueForView: self.valueView];
    }
}

@end
