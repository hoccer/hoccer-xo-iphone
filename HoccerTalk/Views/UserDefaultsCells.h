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

@interface UserDefaultsCell : HoccerTalkTableViewCell

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) count;

@end

@interface UserDefaultsCellAvatarPicker : UserDefaultsCell

@property (nonatomic,strong) IBOutlet ProfileAvatarView * avatar;

@end


@interface UserDefaultsCellTextInput : UserDefaultsCell

@property (nonatomic,strong) IBOutlet UITextField * textField;
@property (nonatomic,strong) IBOutlet UIImageView * textInputBackground;

@end

@interface UserDefaultsCellSwitch: UserDefaultsCell

@property (nonatomic,strong) IBOutlet UISwitch * toggle;

@end

@interface UserDefaultsCellInfoText : UserDefaultsCell

@property (nonatomic,strong) IBOutlet UILabel * textLabel;

@end

