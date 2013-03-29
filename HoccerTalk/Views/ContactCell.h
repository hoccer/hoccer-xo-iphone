//
//  ContactCell.h
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class InsetImageView;

@interface ContactCell : UITableViewCell

@property (nonatomic,strong) IBOutlet UILabel * nickName;
@property (nonatomic,strong) IBOutlet InsetImageView * avatar;


+ (NSString *)reuseIdentifier;
- (void) setMessageCount: (NSInteger) count isUnread: (BOOL) unreadFlag;

@end
