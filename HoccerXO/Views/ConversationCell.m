//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationCell.h"

#import <QuartzCore/QuartzCore.h>

extern const CGFloat kHXOGridSpacing;

static const CGFloat kHXOTimeDirectionPading = 2.0;

@interface ConversationCell ()
{
    BOOL _hasNewMessages;
}

@property (nonatomic,strong) UIView * ourAccessoryView;
@end

@implementation ConversationCell

- (void) commonInit {
    [super commonInit];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    //self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.accessoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 16)];
    [self.accessoryView setTranslatesAutoresizingMaskIntoConstraints: NO];
    
    
}

- (void) setHasNewMessages:(BOOL)hasNewMessages {
    _hasNewMessages = hasNewMessages;
}


- (void) layoutSubviews {
    [super layoutSubviews];
    if ( ! self.ourAccessoryView) {
        CGRect frame = self.accessoryView.frame;
        frame.origin.y = 2 * kHXOGridSpacing;
        self.ourAccessoryView = [[UIView alloc] initWithFrame: frame];
        self.ourAccessoryView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        self.ourAccessoryView.backgroundColor = [UIColor orangeColor];
        [self.accessoryView.superview addSubview: self.ourAccessoryView];
        //self.accessoryView = nil;
    }
}


- (UILabel*) latestMessageLabel {
    return self.statusLabel;
}

@end
