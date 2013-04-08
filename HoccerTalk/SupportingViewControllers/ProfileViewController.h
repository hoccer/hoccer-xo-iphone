//
//  ProfileViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ProfileAvatarCell;
@class ProfileTextCell;
@class AvatarItem;

@interface ProfileViewController : UITableViewController <UITextFieldDelegate>
{
    AvatarItem *        _avatarItem;
    NSMutableArray *    _profileItems;
    ProfileAvatarCell * _avatarCell;
    ProfileTextCell *   _textCell;
    BOOL                _editing;
}

@property (nonatomic,strong) UITableView* tableView;

@end
