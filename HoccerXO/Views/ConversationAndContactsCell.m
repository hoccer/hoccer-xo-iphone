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

/*
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
    frame.size.height = 10 * kHXOGridSpacing;
    self.frame = frame;
    
    frame = CGRectMake( 2 * kHXOGridSpacing, 2 * kHXOGridSpacing, 6 * kHXOGridSpacing, 6 * kHXOGridSpacing);
    HXOAvatarButton * avatar = self.avatar = [[HXOAvatarButton alloc] initWithFrame: frame];
    self.avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.contentView addSubview: self.avatar];
    
    CGFloat x = CGRectGetMaxX(frame) + kHXOGridSpacing;
    CGFloat w = self.contentView.frame.size.width - x;
    UIFont * font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    NickNameLabelWithStatus * nickName = self.nickName = [[NickNameLabelWithStatus alloc] initWithFrame: CGRectMake(x, 2 * kHXOGridSpacing, w, font.lineHeight)];
    self.nickName.font = font;
    self.nickName.autoresizingMask = 0;//UIViewAutoresizingFlexibleWidth;
    [self.nickName setTranslatesAutoresizingMaskIntoConstraints: NO];
    [self.contentView addSubview: self.nickName];
    
    
    
    font = [UIFont preferredFontForTextStyle: UIFontTextStyleFootnote];
    UILabel * statusLabel = self.statusLabel = [[UILabel alloc] initWithFrame: CGRectMake(x, 5 * kHXOGridSpacing, w, font.lineHeight * 2)];
    self.statusLabel.font = font;
    self.statusLabel.textColor = [UIColor colorWithWhite: 0.6 alpha: 1.0];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.statusLabel setTranslatesAutoresizingMaskIntoConstraints: NO];
    [self.contentView addSubview: self.statusLabel];

    NSDictionary *viewsDictionary =
    NSDictionaryOfVariableBindings(avatar, nickName, statusLabel);
    NSMutableArray * constraints = [NSMutableArray array];
    [constraints addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-16-[nickName]->=24-[statusLabel]"
                                            options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-80-[nickName]-8-|"
                                                                              options:0 metrics:nil views:viewsDictionary]];
    [constraints addObjectsFromArray: [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-80-[statusLabel]-8-|"
                                                                              options:0 metrics:nil views:viewsDictionary]];
    [self.contentView addConstraints: constraints];

    //self.statusLabel.backgroundColor = [UIColor orangeColor];
    //self.nickName.backgroundColor = [UIColor orangeColor];
}

@end

*/