//
//  ContactCell.h
//  HoccerTalk
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@class InsetImageView;

@interface ConversationCell : HoccerTalkTableViewCell   

@property (nonatomic,strong) IBOutlet UILabel * nickName;
@property (nonatomic,strong) IBOutlet InsetImageView * avatar;
@property (nonatomic,strong) IBOutlet UILabel* latestMessage;
@property (nonatomic,strong) IBOutlet UILabel* latestMessageTime;

@end
