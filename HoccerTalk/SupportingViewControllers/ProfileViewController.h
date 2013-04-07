//
//  ProfileViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ProfileViewController : UITableViewController <UITextFieldDelegate>
{
    NSArray * _profileItems;
    UIImage * _previousNavigationBarBackgroundImage;
    UITableViewCell * _avatarCell;
    UITableViewCell * _normalCell;
}

@property (nonatomic,strong) UITableView* tableView;

@end
