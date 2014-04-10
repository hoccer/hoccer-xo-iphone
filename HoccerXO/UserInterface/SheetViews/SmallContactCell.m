//
//  GroupMemberCell.m
//  HoccerXO
//
//  Created by David Siegel on 08.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SmallContactCell.h"

#import "HXOUI.h"
#import "AvatarView.h"

@implementation SmallContactCell

- (void) commonInit {
    [super commonInit];

    self.contentView.autoresizingMask |= UIViewAutoresizingFlexibleHeight;

    self.titleLabel.text = @"Lorem";

    _avatar = [[AvatarView alloc] initWithFrame: CGRectMake(0, 0, 10, 10)];
    _avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview: _avatar];

    _subtitleLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.font = [HXOUI theme].smallTextFont;
    _subtitleLabel.textColor = [HXOUI theme].lightTextColor;

    [self.contentView addSubview: _subtitleLabel];

    NSDictionary * views = @{@"avatar": self.avatar, @"title": self.titleLabel, @"status": self.subtitleLabel};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[avatar(>=23)]-%f-[title]-(>=%f)-[status]-%f-|", kHXOCellPadding, kHXOCellPadding, kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.subtitleLabel attribute: NSLayoutAttributeBaseline relatedBy: NSLayoutRelationEqual toItem: self.titleLabel attribute: NSLayoutAttributeBaseline multiplier: 1 constant: 0]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.avatar attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual toItem: self.avatar attribute: NSLayoutAttributeHeight multiplier: 1 constant: 0]];

    format = [NSString stringWithFormat: @"V:|-%f-[avatar]-%f-|", kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
}

@end
