//
//  ContactCell.h
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@class InsetImageView;

@interface ContactCell : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet UILabel * nickName;
@property (nonatomic,strong) IBOutlet InsetImageView * avatar;

- (void) setMessageCount: (NSInteger) count isUnread: (BOOL) unreadFlag;

@end

@interface ContactSectionHeaderCell : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet UILabel     * title;
@property (nonatomic,strong) IBOutlet UIImageView * icon;
@end
