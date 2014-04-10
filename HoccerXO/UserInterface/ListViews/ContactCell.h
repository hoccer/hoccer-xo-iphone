//
//  ContactCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class AvatarView;

@interface ContactCell : HXOTableViewCell

@property (nonatomic,readonly) UILabel    * titleLabel;
@property (nonatomic,readonly) UILabel    * subtitleLabel;
@property (nonatomic,readonly) AvatarView * avatar;

- (void) commonInit;
- (void) preferredContentSizeChanged: (NSNotification*) notification;

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views;

- (CGFloat) avatarSize;
- (CGFloat) verticalPadding;


@end
