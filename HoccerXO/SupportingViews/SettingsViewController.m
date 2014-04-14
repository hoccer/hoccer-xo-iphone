//
//  SettingsViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsViewController.h"

#import "IASKSpecifierValuesViewController.h"

#import "UserProfile.h"
#import "DatasheetViewController.h"

@implementation SettingsViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = self.parentViewController.tabBarItem.title;
    self.delegate = self;
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    NSString * segueIdentifier = specifier.key;
    [self performSegueWithIdentifier: segueIdentifier sender: self];
}

@end
