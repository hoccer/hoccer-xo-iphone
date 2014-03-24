//
//  SettingsViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsViewController.h"

#import "IASKSpecifierValuesViewController.h"

#import "UserDefaultsCells.h"

@implementation SettingsViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = self.parentViewController.tabBarItem.title;
    self.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    NSString * storyboardId;
    if ([specifier.key isEqualToString: @"tutorial"]) {
        storyboardId = @"tutorialViewController";
    } else if ([specifier.key isEqualToString: @"faq"]) {
        storyboardId = @"faqViewController";
    } else if ([specifier.key isEqualToString: @"about"]) {
        storyboardId = @"aboutViewController";
    } else if ([specifier.key isEqualToString: @"testingGround"]) {
        storyboardId = @"testingGround";
    } else if ([specifier.key isEqualToString: @"datasheetTesting"]) {
        storyboardId = @"datasheetTesting";
    } else if ([specifier.key isEqualToString: @"webServer"]) {
#ifdef WITH_WEBSERVER
        storyboardId = @"serverViewController";
#else
        NSLog(@"Web server is not enabled in this build");
#endif
    } else if ([specifier.key isEqualToString: @"qrScanner"]) {
        storyboardId = @"nativeQRScanner";
    } else {
        NSLog(@"unhandled button in settings plist (key:%@)", specifier.key);
    }

    if ( ! storyboardId) {
        return;
    }

    UIViewController * vc = self;
    while (vc.storyboard == nil) {
        vc = vc.parentViewController;
    }
    vc = [vc.storyboard instantiateViewControllerWithIdentifier: storyboardId];
    [self.navigationController pushViewController: vc animated: YES];
}

@end
