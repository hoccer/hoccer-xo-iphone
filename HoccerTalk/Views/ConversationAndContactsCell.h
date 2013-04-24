//
//  ConversationAndContactsCell.h
//  HoccerTalk
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@class InsetImageView;

@interface ConversationAndContactsCell : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet UILabel * nickName;
@property (nonatomic,strong) IBOutlet InsetImageView * avatar;
@property (nonatomic,assign) BOOL hasNewMessages;

- (void) engraveLabel: (UILabel*) label;

@end
