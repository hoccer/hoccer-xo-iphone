//
//  DatasheetTextInputCell.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetTextInputCell.h"

extern const CGFloat kHXOGridSpacing;

@implementation DatasheetTextInputCell

- (void) commonInit {
    [super commonInit];

    _valueView = [[UITextField alloc] initWithFrame:CGRectZero];
    self.valueView.autoresizingMask = UIViewAutoresizingNone;
    self.valueView.translatesAutoresizingMaskIntoConstraints = NO;
    self.valueView.font = self.titleLabel.font;
    self.valueView.text = @"Value";
    self.valueView.delegate = self;
    //self.valueView.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.valueView addTarget: self action: @selector(valueDidChange:) forControlEvents: UIControlEventEditingChanged];
    [self.contentView addSubview: self.valueView];
    NSDictionary * views = @{@"title": self.titleLabel, @"value": self.valueView};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[title]-%f-[value(>=200)]-%f-|", 2 * kHXOGridSpacing, kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.valueView attribute: NSLayoutAttributeBaseline relatedBy: NSLayoutRelationEqual toItem: self.titleLabel attribute: NSLayoutAttributeBaseline multiplier: 1.0 constant: 0.0]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.valueView attribute: NSLayoutAttributeHeight relatedBy: NSLayoutRelationEqual toItem: self.titleLabel attribute: NSLayoutAttributeHeight multiplier: 1.0 constant: 0.0]];
}

- (void) preferredContentSizeChanged:(NSNotification *)notification {
    [super preferredContentSizeChanged: notification];
    self.valueView.font = self.titleLabel.font;
}

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString * newValue = [textField.text stringByReplacingCharactersInRange: range withString: string];
    return [self.delegate respondsToSelector: @selector(datasheetCell:shouldChangeValue:toNewValue:)] ?
        [self.delegate datasheetCell: self shouldChangeValue: textField.text toNewValue: newValue] : YES;
}

- (void) valueDidChange: (id) sender {
    if ([self.delegate respondsToSelector: @selector(datasheetCell:didChangeValueForView:)]) {
        [self.delegate datasheetCell: self didChangeValueForView: self.valueView];
    }
}

@end
