//
//  SettingsViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsViewController.h"

#import "IASKSpecifierValuesViewController.h"

#import "UIViewController+HXOSideMenu.h"
#import "UserDefaultsCells.h"

@implementation SettingsViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];

    self.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    
}

@end
