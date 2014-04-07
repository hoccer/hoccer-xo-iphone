//
//  DatasheetFooterTextView.m
//  HoccerXO
//
//  Created by David Siegel on 27.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetFooterTextView.h"

#import "HXOHyperLabel.h"
#import "HXOUI.h"


@interface DatasheetFooterTextView ()

@property (nonatomic,strong) NSLayoutConstraint * topPadding;
@property (nonatomic,strong) NSLayoutConstraint * bottomPadding;

@end


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

    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //self.contentView.translatesAutoresizingMaskIntoConstraints = NO;

    //self.contentView.backgroundColor = [UIColor lightGrayColor];


    self.label = [[HXOHyperLabel alloc] initWithFrame: self.bounds];
    self.label.autoresizingMask = UIViewAutoresizingNone;
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
    //self.label.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    //self.label.backgroundColor = [UIColor orangeColor];
    [self.contentView addSubview: self.label];

    NSDictionary * views = @{@"label": self.label};
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[label]-(>=%f)-|", kHXOCellPadding, kHXOCellPadding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];


    // TODO find out why these don't work ...
    self.topPadding = [NSLayoutConstraint constraintWithItem: self.contentView attribute: NSLayoutAttributeTop relatedBy: NSLayoutRelationEqual toItem: self.label attribute:NSLayoutAttributeTop multiplier: 1.0 constant: kHXOGridSpacing];
    //[self.contentView addConstraint: self.topPadding];

    self.bottomPadding = [NSLayoutConstraint constraintWithItem: self.contentView attribute: NSLayoutAttributeBottom relatedBy: NSLayoutRelationEqual toItem: self.label attribute:NSLayoutAttributeBottom multiplier: 1.0 constant: 2 * kHXOGridSpacing];
    //[self.contentView addConstraint: self.bottomPadding];


    // ... for now use this :-/
    format = [NSString stringWithFormat: @"V:|-%f-[label]-%f-|", kHXOGridSpacing, kHXOCellPadding];
    NSArray * array =  [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views];
    self.topPadding = [array firstObject];
    self.bottomPadding = array[1];
    [self.contentView addConstraints: array];
}

+ (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

- (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

- (void) setLabelPadding:(UIEdgeInsets)labelPadding {
    _labelPadding = labelPadding;
    self.topPadding.constant = labelPadding.top;
    self.bottomPadding.constant = labelPadding.bottom;
}

@end
