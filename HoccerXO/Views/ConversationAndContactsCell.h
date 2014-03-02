//
//  ConversationAndContactsCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "NickNameLabelWithStatus.h"
#import "HXOAvatarButton.h"

@interface ConversationAndContactsCell : HXOTableViewCell

@property (nonatomic,strong) NickNameLabelWithStatus * nickName;
@property (nonatomic,strong) HXOAvatarButton * avatar;
@property (nonatomic,strong) UILabel * statusLabel;

- (void) commonInit;

@end
