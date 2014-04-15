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

#import "tab_settings.h"

@implementation SettingsViewController

- (void) awakeFromNib {
    [super awakeFromNib];
    self.title = NSLocalizedString(@"settings_nav_title", nil);
    self.tabBarItem.image = [[tab_settings alloc] init].image;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    self.delegate = self;
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    NSString * segueIdentifier = specifier.key;
    [self performSegueWithIdentifier: segueIdentifier sender: self];
}

@end
