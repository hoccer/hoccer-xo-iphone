//
//  GroupMemberCell.h
//  HoccerXO
//
//  Created by David Siegel on 08.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetCell.h"

#import "ContactCellProtocol.h"

@class AvatarView;

@interface SmallContactCell : DatasheetCell <ContactCell>

@property (nonatomic, readonly) AvatarView * avatar;
@property (nonatomic, readonly) UILabel    * subtitleLabel;

@property (nonatomic, assign)   BOOL         closingSeparator;

@end
