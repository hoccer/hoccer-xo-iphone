//
//  ProfileViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AttachmentPickerController.h"

@class UserDefaultsCellAvatarPicker;
@class UserDefaultsCellTextInput;
@class AvatarItem;

@interface ProfileViewController : UITableViewController <UITextFieldDelegate,AttachmentPickerControllerDelegate>
{
    AvatarItem *        _avatarItem;
    NSMutableArray *    _profileItems;
    UserDefaultsCellAvatarPicker * _avatarCell;
    UserDefaultsCellTextInput *   _textCell;
    BOOL                _editing;
}

@property (nonatomic,strong) UITableView* tableView;

@end
