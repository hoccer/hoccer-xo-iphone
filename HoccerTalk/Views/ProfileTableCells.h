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

@interface UserDefaultsCellAvatarPicker : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet ProfileAvatarView * avatar;

@end


@interface UserDefaultsCellTextInput : HoccerTalkTableViewCell

@property (nonatomic,strong) IBOutlet UITextField * textField;
@property (nonatomic,strong) IBOutlet UIImageView * textInputBackground;

@end
