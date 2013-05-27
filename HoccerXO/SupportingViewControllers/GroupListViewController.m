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
#import "GroupViewController.h"

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

- (void) addContactPredicates: (NSMutableArray*) predicates {
    [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@", [self entityName]]];
}

- (NSString*) entityName {
    return [Group entityName];
}

- (NSString*) emptyTablePlaceholderKey {
    return @"groups_empty_placeholder";
}


- (NSString*) defaultAvatarName {
    return @"avatar_default_group";
}

- (NSString*) navigationItemBackButtonImageName {
    return @"navigation_button_groups";
}

- (void) addButtonPressed: (id) sender {
    UINavigationController * modalGroupView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalGroupViewController"];
    [self presentViewController: modalGroupView animated: YES completion:nil];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSLog(@"prepareForSegue: %@", segue.identifier);
    Group * group = nil;
    GroupViewController * groupViewController = (GroupViewController*)segue.destinationViewController;
    if ([[segue identifier] isEqualToString:@"showGroup"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        group = [[self currentFetchedResultsController] objectAtIndexPath:indexPath];
    }
    groupViewController.group = group;
}

@end
