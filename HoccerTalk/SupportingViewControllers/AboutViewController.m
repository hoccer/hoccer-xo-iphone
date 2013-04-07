//
//  AboutViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AboutViewController.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"

@implementation AboutViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hoccerTalkMenuButton];
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
}

@end
