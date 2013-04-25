//
//  TutorialViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TutorialViewController.h"
#import "UIViewController+HXOSideMenuButtons.h"

@implementation TutorialViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
}

@end
