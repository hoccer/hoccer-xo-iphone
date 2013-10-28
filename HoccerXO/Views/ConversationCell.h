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

@class InsetImageView;

@interface ConversationCell : ConversationAndContactsCell

@property (nonatomic,strong) IBOutlet UILabel* latestMessageLabel;
@property (nonatomic,strong) IBOutlet UILabel* latestMessageTimeLabel;

@property (nonatomic,strong) IBOutlet UIImageView* latestMessageDirection;

@property (nonatomic,strong) UIView * unreadMessageBackground;

@property (nonatomic,assign) BOOL hasNewMessages;

@end
