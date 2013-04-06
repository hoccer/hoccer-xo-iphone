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

@implementation ProfileViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hoccerTalkMenuButton];
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];

    self.clientIdField.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.clientIdField.text = [[HTUserDefaults standardUserDefaults] objectForKey: kHTClientId];
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.clientIdField) {
        NSLog(@"new clientId: %@", textField.text);
        [[HTUserDefaults standardUserDefaults] setObject: textField.text forKey: kHTClientId];
        [[HTUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)viewDidUnload {
    [self setClientIdField:nil];
    [super viewDidUnload];
}
@end
