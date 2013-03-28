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

@implementation ProfileViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hoccerTalkMenuButton];
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];

    self.clientIdField.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.clientIdField.text = [[NSUserDefaults standardUserDefaults] objectForKey: @"clientId"];
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.clientIdField) {
        NSLog(@"new clientId: %@", textField.text);
        [[NSUserDefaults standardUserDefaults] setObject: textField.text forKey: @"clientId"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)viewDidUnload {
    [self setClientIdField:nil];
    [super viewDidUnload];
}
@end
