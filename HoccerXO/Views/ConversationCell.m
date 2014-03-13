//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationCell.h"

#import <QuartzCore/QuartzCore.h>
#import "VectorArtView.h"

extern const CGFloat kHXOGridSpacing;

static const CGFloat kHXOTimeDirectionPading = 2.0;

@interface ConversationCell ()

@property (nonatomic,strong) UIView  * actualAccessoryView;

@end


@implementation ConversationCell

- (void) commonInit {
    
    _dateLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.autoresizingMask = UIViewAutoresizingNone;
    _dateLabel.numberOfLines = 1;
    _dateLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleFootnote];
    _dateLabel.text = @"jetze";
    //_dateLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: _dateLabel];

    [super commonInit];
    
    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: _dateLabel attribute: NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem: self.nickName attribute: NSLayoutAttributeBaseline multiplier: 1.0 constant: 0.0]];
    
    VectorArtView * accessoryView = [VectorArtView disclosureArrow];
    self.accessoryView = [[UIView alloc] initWithFrame: accessoryView.frame];
    CGRect frame = accessoryView.frame;
    frame.origin.x = self.frame.size.width - (frame.size.width + kHXOGridSpacing);
    frame.origin.y = kPadding;
    accessoryView.frame = frame;
    self.actualAccessoryView = accessoryView;
    self.actualAccessoryView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    //self.actualAccessoryView.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    
    [self addSubview: self.actualAccessoryView];
    
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.text = @"Lorem\nIpsum\n";

}

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views {
    NSMutableDictionary * v = [NSMutableDictionary dictionaryWithDictionary: views];
    v[@"date"] = self.dateLabel;
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[image(%f)]-%f-[title]->=%f-[date]|", 16.0, 6.0 * 8, 16.0, 16.0];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: v]];
    
    format = [NSString stringWithFormat:  @"H:[image]-%f-[subtitle]|", kPadding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];

    
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    [super preferredContentSizeChanged: notification];
    
    self.dateLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleFootnote];
}

@end
