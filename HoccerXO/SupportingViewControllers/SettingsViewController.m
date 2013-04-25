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
#import "UserDefaultsCells.h"

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
    [self setNavigationBarBackgroundWithLines];
}

- (void) populateSettingsItem {
    /*
    SettingsItem * saveContent = [SettingsItem item];
    saveContent.cellIdentifier = [UserDefaultsCellSwitch reuseIdentifier];
    saveContent.label = NSLocalizedString(@"setting_save_incoming_media", nil);

    SettingsItem * saveContentInfo = [SettingsItem item];
    saveContentInfo.cellIdentifier = [UserDefaultsCellInfoText reuseIdentifier];
    saveContentInfo.label = NSLocalizedString(@"setting_save_incoming_media_info", nil);
    */
    SettingsItem * playSoundOnMessageArrival = [SettingsItem item];
    playSoundOnMessageArrival.cellIdentifier = [UserDefaultsCellSwitch reuseIdentifier];
    playSoundOnMessageArrival.label = NSLocalizedString(@"play_sound_on_message_arrival", nil);
    
    SettingsItem * playSoundOnMessageArrivalInfo = [SettingsItem item];
    playSoundOnMessageArrivalInfo.cellIdentifier = [UserDefaultsCellInfoText reuseIdentifier];
    playSoundOnMessageArrivalInfo.label = NSLocalizedString(@"play_sound_on_message_arrival", nil);

    _items = @[ @[playSoundOnMessageArrival, playSoundOnMessageArrivalInfo ]
              ];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0; //XXX
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SettingsItem * item = _items[indexPath.section][indexPath.row];
    UITableViewCell * cell = [self dequeueReusableCellOfClass: NSClassFromString(item.cellIdentifier) forIndexPath:indexPath];
    cell.textLabel.text = item.label;
    return cell;
}


@end

@implementation SettingsItem

+ (SettingsItem*) item {
    return [[SettingsItem alloc] init];
}

@end