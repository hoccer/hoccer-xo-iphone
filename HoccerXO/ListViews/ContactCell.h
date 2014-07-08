//
//  ContactCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ContactCellProtocol.h"
#import "HXOTableViewCell.h"

@class AvatarView;
@class Contact;
@class ContactCell;

@protocol ContactCellDelegate <NSObject>
- (void) contactCellDidPressAvatar: (ContactCell*) cell;
@end

@interface ContactCell : HXOTableViewCell <ContactCell>

@property (nonatomic,readonly) UILabel                 * titleLabel;
@property (nonatomic,readonly) UILabel                 * subtitleLabel;
@property (nonatomic,readonly) AvatarView              * avatar;
@property (nonatomic, weak)    id<ContactCellDelegate>   delegate;

- (void) commonInit;
- (void) preferredContentSizeChanged: (NSNotification*) notification;

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views;

- (CGFloat) avatarSize;
- (CGFloat) verticalPadding;
- (CGFloat) labelSpacing;

+ (void) configureCell:(UITableViewCell<ContactCell> *)cell forContact: (Contact *)contact;

@end
