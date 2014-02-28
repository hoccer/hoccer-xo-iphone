//
//  ConversationAndContactsCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationAndContactsCell.h"
#import "QuartzCore/QuartzCore.h"

extern const CGFloat kHXOGridSpacing;

@implementation ConversationAndContactsCell

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    CGRect frame = self.frame;
    frame.size.height = 7 * kHXOGridSpacing;
    self.frame = frame;
    
    frame = CGRectMake( 2 * kHXOGridSpacing, 1 * kHXOGridSpacing, 5 * kHXOGridSpacing, 5 * kHXOGridSpacing);
    self.avatar = [[HXOAvatarButton alloc] initWithFrame: frame];
    [self.contentView addSubview: self.avatar];
    
    
    CGFloat x = CGRectGetMaxX(frame) + kHXOGridSpacing;
    self.nickName = [[NickNameLabelWithStatus alloc] initWithFrame: CGRectMake(x, kHXOGridSpacing, self.bounds.size.width - x, 3 * kHXOGridSpacing)];
    self.nickName.font = [UIFont preferredFontForTextStyle: UIFontTextStyleHeadline];
    [self.contentView addSubview: self.nickName];
    
    self.statusLabel = [[UILabel alloc] initWithFrame: CGRectMake(x, 4 * kHXOGridSpacing, self.bounds.size.width - x, 2 * kHXOGridSpacing)];
    self.statusLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleFootnote];
    self.statusLabel.textColor = [UIColor colorWithWhite: 0.6 alpha: 1.0];
    [self.contentView addSubview: self.statusLabel];
}

@end
