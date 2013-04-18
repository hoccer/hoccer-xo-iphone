//
//  ProfileViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AttachmentPickerController.h"

#import "UserDefaultsViewController.h"

@class UserDefaultsCellAvatarPicker;
@class UserDefaultsCellTextInput;
@class AvatarItem;
@class Contact;
@class ProfileItem;

typedef enum ProfileViewModes {
    ProfileViewModeFirstRun,
    ProfileViewModeMyProfile,
    ProfileViewModeContactProfile
} ProfileViewMode;

@interface ProfileViewController : UserDefaultsViewController <AttachmentPickerControllerDelegate>
{
    AvatarItem *      _avatarItem;
    ProfileItem *     _chatWithContactItem;
    ProfileItem *     _blockContactItem;
    ProfileItem *     _fingerprintItem;
    ProfileItem *     _fingerprintInfoItem;
    NSArray *         _profileItems;
    NSMutableArray *  _allProfileItems;
    ProfileViewMode   _mode;
    BOOL              _canceled;
}


@property (nonatomic,strong) Contact* contact;

@end
