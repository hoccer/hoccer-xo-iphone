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

@interface ConversationAndContactsCell : HXOTableViewCell

@property (nonatomic,strong) IBOutlet NickNameLabelWithStatus * nickName;
@property (nonatomic,strong) IBOutlet UIImageView * avatar;
@property (nonatomic,strong) IBOutlet UILabel * statusLabel;

@end
