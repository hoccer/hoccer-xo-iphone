//
//  GroupsViewController.m
//  HoccerXO
//
//  Created by David Siegel on 15.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupListViewController.h"
#import "Group.h"
#import "AppDelegate.h"
#import "HXOBackend.h"

@interface GroupListViewController ()

@end

@implementation GroupListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString*) entityName {
    return [Group entityName];
}

- (NSString*) emptyTablePlaceholderKey {
    return @"groups_empty_placeholder";
}

- (void) addButtonPressed: (id) sender {
    Group * group = [self.backend createGroup];
    group.nickName = @"Tolle Gruppe";
}

- (HXOBackend*) backend {
    return ((AppDelegate*)UIApplication.sharedApplication.delegate).chatBackend;
}

- (NSString*) defaultAvatarName {
    return @"avatar_default_group";
}

@end
