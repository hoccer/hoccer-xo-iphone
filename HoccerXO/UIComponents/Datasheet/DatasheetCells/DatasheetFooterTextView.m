//
//  DatasheetFooterTextView.m
//  HoccerXO
//
//  Created by David Siegel on 27.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetFooterTextView.h"

#import "HXOHyperLabel.h"
#import "HXOTheme.h"

extern const CGFloat kHXOGridSpacing;

@implementation DatasheetFooterTextView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {

    //self.contentView.backgroundColor = [UIColor orangeColor];

    self.contentView.autoresizingMask |= UIViewAutoresizingFlexibleHeight;


    self.label = [[HXOHyperLabel alloc] initWithFrame: self.bounds];
    self.label.font = [HXOTheme theme].smallTextFont;
    self.label.autoresizingMask = UIViewAutoresizingNone;
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
    self.label.textColor = [HXOTheme theme].smallBoldTextColor;
    //self.label.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: self.label];

    NSDictionary * views = @{@"label": self.label};
    CGFloat padding = 2 * kHXOGridSpacing;
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[label]-%f-|", padding, padding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
    format = [NSString stringWithFormat: @"V:|-%f-[label]-%f-|", kHXOGridSpacing, padding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
}

+ (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

- (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

@end
