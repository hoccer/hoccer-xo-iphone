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
#import "WebViewController.h"

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
    NSString * url;
    if ([specifier.key isEqualToString: @"showTutorial"]) {
        url = @"http://hoccer.com/hoccer-xo-tutorial/";
    } else if ([specifier.key isEqualToString: @"showFaq"]) {
        url = @"http://hoccer.com/hoccer-xo-faq/";
    }
    if (url){
        [self performSegueWithIdentifier: @"showURL" sender: url];
    } else {
        [self performSegueWithIdentifier: specifier.key sender: self];
    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString: @"showURL"]) {
        ((WebViewController*)((UINavigationController*)segue.destinationViewController).viewControllers[0]).homeUrl = sender;
    }
}

@end
