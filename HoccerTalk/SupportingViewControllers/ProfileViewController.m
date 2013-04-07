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

@interface ProfileItem : NSObject

@property (nonatomic,strong) UIImage * icon;
@property (nonatomic,strong) NSString * userDefaultsKey;

@end

@implementation ProfileViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        ProfileItem * avatarItem = [[ProfileItem alloc] init];
        avatarItem.icon = nil;
        avatarItem.userDefaultsKey = kHTAvatarImage;

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

}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_profileItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0") ?
        [tableView dequeueReusableCellWithIdentifier: @"profileCell" forIndexPath:indexPath] :
        [tableView dequeueReusableCellWithIdentifier: @"profileCell"];
    ProfileItem * item = (ProfileItem*)_profileItems[indexPath.row];

    cell.textLabel.text = [[HTUserDefaults standardUserDefaults] valueForKey: item.userDefaultsKey];
    cell.imageView.image = item.icon;

    return cell;
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