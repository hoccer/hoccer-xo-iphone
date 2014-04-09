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
#import "HXOUI.h"
#import "DisclosureArrow.h"
#import "HXOUI.h"

@implementation ConversationCell

- (void) commonInit {

    self.hxoAccessoryPadding = kHXOGridSpacing;
    
    _dateLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _dateLabel.autoresizingMask = UIViewAutoresizingNone;
    _dateLabel.numberOfLines = 1;
    _dateLabel.textColor = [[HXOUI theme] smallBoldTextColor];
    _dateLabel.text = @"jetze";
    //_dateLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: _dateLabel];

    [super commonInit];
    
    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: _dateLabel attribute: NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem: self.nickName attribute: NSLayoutAttributeBaseline multiplier: 1.0 constant: 0.0]];

    self.hxoAccessoryView = [[VectorArtView alloc] initWithVectorArt: [[DisclosureArrow alloc] init]];
    self.hxoAccessoryAlignment = HXOCellAccessoryAlignmentTop;

    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.text = @"Lorem\nIpsum";
    //self.subtitleLabel.backgroundColor = [UIColor orangeColor];

}

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views {
    self.dateLabel.font = [[HXOUI theme] smallBoldTextFont];
    NSMutableDictionary * v = [NSMutableDictionary dictionaryWithDictionary: views];
    v[@"date"] = self.dateLabel;
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[image(%f)]-%f-[title]->=%f-[date]|", kHXOCellPadding, kHXOListAvatarSize, kHXOCellPadding, kHXOCellPadding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: v]];
    
    format = [NSString stringWithFormat:  @"H:[image]-%f-[subtitle]|", kHXOCellPadding];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];

    
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    [super preferredContentSizeChanged: notification];
    
    self.dateLabel.font = [HXOUI theme].smallBoldTextFont;
}

@end
