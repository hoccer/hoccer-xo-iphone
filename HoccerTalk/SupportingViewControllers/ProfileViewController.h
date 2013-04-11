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

@interface ProfileViewController : UserDefaultsViewController <UITextFieldDelegate,AttachmentPickerControllerDelegate>
{
    AvatarItem *        _avatarItem;
    NSMutableArray *    _profileItems;
    BOOL                _editing;
}

@property (nonatomic,strong) UITableView* tableView;

@end
