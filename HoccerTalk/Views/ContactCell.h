//
//  ContactCell.h
//  HoccerTalk
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AvatarBezelView;

@interface ContactCell : UITableViewCell

@property (nonatomic,strong) IBOutlet UILabel * nickName;
@property (nonatomic,strong) IBOutlet AvatarBezelView * avatar;
@property (nonatomic, assign) NSInteger messageCount;

@property (nonatomic,assign) BOOL hasUnreadMessages;

+ (NSString *)reuseIdentifier;

@end
