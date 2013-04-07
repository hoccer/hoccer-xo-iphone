//
//  ProfileViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileViewController.h"
#import "MFSideMenu.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "HTUserDefaults.h"
#import "iOSVersionChecks.h"
#import "AssetStore.h"
#import "ProfileAvatarCell.h"
#import "ProfileAvatarView.h"

@interface ProfileItem : NSObject

@property (nonatomic,strong) UIImage * icon;
@property (nonatomic,strong) NSString * userDefaultsKey;

@end

@implementation ProfileViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        ProfileItem * nickNameItem = [[ProfileItem alloc] init];
        nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
        nickNameItem.userDefaultsKey = kHTNickName;

        _profileItems = @[nickNameItem];
    }
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hoccerTalkMenuButton];
    UIBarButtonItem *editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(onEdit:)];
    self.navigationItem.rightBarButtonItem = editButton;

    UIView * backgroundView = [[UIView alloc] initWithFrame: self.tableView.bounds];
    backgroundView.backgroundColor = [UIColor whiteColor];
    self.tableView.backgroundView = backgroundView;

    _avatarCell = [self.tableView dequeueReusableCellWithIdentifier: @"avatarCell"];
    _normalCell = [self.tableView dequeueReusableCellWithIdentifier: @"profileCell"];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return [_profileItems count];
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return _avatarCell.bounds.size.height;
    } else {
        return _normalCell.bounds.size.height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = nil;
    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier: @"avatarCell" forIndexPath:indexPath];
        cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];
        ((ProfileAvatarCell*)cell).avatar.image = [UIImage imageWithData: [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarImage]];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier: @"profileCell" forIndexPath:indexPath];
        ProfileItem * item = (ProfileItem*)_profileItems[indexPath.row];

        cell.textLabel.text = [[HTUserDefaults standardUserDefaults] valueForKey: item.userDefaultsKey];
        cell.textLabel.textColor = [UIColor colorWithWhite: 0.2 alpha: 1.0];
        cell.imageView.image = item.icon;
    }
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
}

- (IBAction)onEdit:(id)sender {
    
}

- (void)viewDidUnload {
    [super viewDidUnload];
}
@end

@implementation ProfileItem
@end