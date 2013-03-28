//
//  UIViewController+HoccerTalkSideMenuButtons.m
//  HoccerTalk
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "MFSideMenu.h"

@implementation UIViewController (HoccerTalkSideMenuButtons)

- (UIBarButtonItem*) hoccerTalkMenuButton {
    UIImage * icon = [UIImage imageNamed: @"navbar-icon-menu"];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage: icon landscapeImagePhone: icon style:UIBarButtonItemStylePlain target:self action:@selector(menuButtonPressed:)];
    return button;
}

- (UIBarButtonItem*) hoccerTalkContactsButton {
    UIImage * icon = [UIImage imageNamed: @"navbar-icon-contacts"];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage: icon landscapeImagePhone: icon style:UIBarButtonItemStylePlain target: self action:@selector(contactsButtonPressed:)];
    return button;
}

- (IBAction) menuButtonPressed:(id)sender {
    [self.navigationController.sideMenu toggleLeftSideMenu];
}

- (IBAction) contactsButtonPressed:(id)sender {
    [self.navigationController.sideMenu toggleRightSideMenu];
}

@end
