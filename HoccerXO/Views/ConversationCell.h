//
//  ContactCell.h
//  HoccerXO
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "ConversationAndContactsCell.h"

@interface ConversationCell : ConversationAndContactsCell

@property (nonatomic,readonly) UILabel* latestMessageLabel;
@property (nonatomic,readonly) UILabel* latestMessageTimeLabel;
@property (nonatomic,readonly) UILabel* unreadMessageCountLabel;

@property (nonatomic,assign) BOOL hasNewMessages;

@end
