//
//  ProfileViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileViewController.h"
#import "MFSideMenu.h"

@implementation ProfileViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    UIImage * icon = [UIImage imageNamed: @"navbar-icon-menu"];
    UIBarButtonItem *menuButton = [[UIBarButtonItem alloc] initWithImage: icon landscapeImagePhone: icon style:UIBarButtonItemStylePlain target:self action:@selector(menuButtonPressed:)];
    self.navigationItem.leftBarButtonItem = menuButton;

    self.clientIdField.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    NSLog(@"viewWillAppear");

    self.clientIdField.text = [[NSUserDefaults standardUserDefaults] objectForKey: @"clientId"];
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.clientIdField) {
        NSLog(@"new clientId: %@", textField.text);
        [[NSUserDefaults standardUserDefaults] setObject: textField.text forKey: @"clientId"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
#pragma mark - Actions

- (IBAction) menuButtonPressed:(id)sender {
    [self.navigationController.sideMenu toggleLeftSideMenu];
}


- (void)viewDidUnload {
    [self setClientIdField:nil];
    [super viewDidUnload];
}
@end
