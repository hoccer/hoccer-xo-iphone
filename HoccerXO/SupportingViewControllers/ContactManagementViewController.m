//
//  ContactManagementViewController.m
//  HoccerXO
//
//  Created by David Siegel on 22.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactManagementViewController.h"

@interface ContactManagementViewController ()

@end

@implementation ContactManagementViewController

- (void)viewDidLoad {
    self.childViewControllerStoryboardIDs = @[@"contactsViewController", @"groupListViewController"];
    self.childViewControllerTitles = @[@"contacts_menu_item", @"groups_menu_item"];
    
    [super viewDidLoad];
}

@end
