//
//  DataSheetCell.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DataSheetCell.h"

#import "HXOTheme.h"

#import "HXOLabel.h"

extern const CGFloat kHXOGridSpacing;

@implementation DataSheetCell

- (id)initWithStyle: (UITableViewCellStyle) style reuseIdentifier: (NSString*) reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self) {
        [self commonInit];
        [self preferredContentSizeChanged: nil];
    }
    return self;
}

- (void) commonInit {
    CGFloat padding = 2 * kHXOGridSpacing;

    _titleLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    self.titleLabel.autoresizingMask = UIViewAutoresizingNone;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textColor = [HXOTheme theme].lightTextColor;
    //self.titleLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: self.titleLabel];

    NSDictionary * views = @{@"label": self.titleLabel};
    NSString * format = [NSString stringWithFormat: @"V:|-%f-[label]-%f-|", kHXOGridSpacing, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    self.separatorInset = UIEdgeInsetsMake(0, padding, 0, 0);

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name: UIContentSizeCategoryDidChangeNotification object: nil];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) preferredContentSizeChanged:(NSNotification *)notification {
    self.titleLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];

    [self setNeedsLayout];
}

@end
