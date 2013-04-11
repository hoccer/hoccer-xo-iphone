//
//  SettingsViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsViewController.h"

#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "RadialGradientView.h"
#import "SettingsCells.h"

@interface SettingsItem : NSObject

@property (nonatomic,strong) NSString * cellIdentifier;
@property (nonatomic,strong) NSString * label;

+ (SettingsItem*) item;

@end

@implementation SettingsViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hoccerTalkMenuButton];
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];


    [self populateSettingsItem];
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
}

- (void) populateSettingsItem {
    SettingsItem * saveContent = [SettingsItem item];
    saveContent.cellIdentifier = [SettingSwitchCell reuseIdentifier];
    saveContent.label = NSLocalizedString(@"setting_save_incoming_media", nil);

    SettingsItem * saveContentInfo = [SettingsItem item];
    saveContentInfo.cellIdentifier = [SettingTextCell reuseIdentifier];
    saveContentInfo.label = NSLocalizedString(@"setting_save_incoming_media_info", nil);
    
    _items = @[ @[saveContent, saveContentInfo ]
              ];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0; //XXX
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SettingsItem * item = _items[indexPath.section][indexPath.row];
    UITableViewCell * cell = [self.tableView dequeueReusableCellWithIdentifier: item.cellIdentifier];
    cell.textLabel.text = item.label;
    return cell;
}


@end

@implementation SettingsItem

+ (SettingsItem*) item {
    return [[SettingsItem alloc] init];
}

@end