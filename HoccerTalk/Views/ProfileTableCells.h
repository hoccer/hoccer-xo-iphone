//
//  ProfileAvatarCell.h
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@class ProfileAvatarView;

@interface ProfileAvatarCell : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet ProfileAvatarView * avatar;

@end


@interface ProfileTextCell : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet UITextField * textField;
@property (nonatomic,strong) IBOutlet UIImageView * textInputBackground;

@end
