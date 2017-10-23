//
//  SettingsViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsViewController.h"

#import <LocalAuthentication/LocalAuthentication.h>

#import "IASKSpecifierValuesViewController.h"

#import "UserProfile.h"
#import "DatasheetViewController.h"
#import "WebViewController.h"
#import "SetupViewControllers.h"
#import "AppDelegate.h"

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
    LAContext * ctx = [[LAContext alloc] init];
    NSError * error;
    NSMutableSet * hiddenKeys = [NSMutableSet set];
    if (![ctx canEvaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics error: &error])
    {
        [hiddenKeys addObject: @"AccessControlTouchIdEnabled"];
    }

    // Hide EULA button if no EULA URL is set
    NSURL * eulaURL = [(AppDelegate*)[UIApplication sharedApplication].delegate eulaURL];
    if (!eulaURL) {
        [hiddenKeys addObject: @"show_eula"];
    }
    self.hiddenKeys = hiddenKeys;
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    NSString * url;
    if ([specifier.key isEqualToString: @"showTutorial"]) {
        url = @"hoccer_tutorial_url";
    } else if ([specifier.key isEqualToString: @"showFaq"]) {
        url = @"hoccer_faq_url";
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
    } else if ([segue.identifier isEqualToString: @"show_eula"]) {
        ((EulaViewController*)segue.destinationViewController).accept = NO;
    }
}

@end
