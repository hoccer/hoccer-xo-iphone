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
#import "ContactCell.h"
#import "InsetImageView.h"
#import "GroupMembership.h"

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
    // NSLog(@"prepareForSegue: %@", segue.identifier);
    Group * group = nil;
    GroupViewController * groupViewController = (GroupViewController*)segue.destinationViewController;
    if ([[segue identifier] isEqualToString:@"showGroup"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        group = [[self currentFetchedResultsController] objectAtIndexPath:indexPath];
    }
    groupViewController.group = group;
}

- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)cell
                     atIndexPath:(NSIndexPath *)indexPath
{
    // your cell guts here
    Group * group = (Group*)[fetchedResultsController objectAtIndexPath:indexPath];
    // cell.nickName.text = contact.nickName;
    cell.nickName.text = group.nickName;
    
    cell.avatar.image = group.avatarImage != nil ? group.avatarImage : [UIImage imageNamed: [self defaultAvatarName]];
    
    NSInteger joinedMemberCount = [group.otherJoinedMembers count];
    NSInteger invitedMemberCount = [group.otherInvitedMembers count];
    
    NSString * joinedStatus = @"";
    
    if ([group.groupState isEqualToString:@"kept"]) {
        joinedStatus = NSLocalizedString(@"Group Deactivated", nil);
    } else if ([group.myGroupMembership.state isEqualToString:@"invited"]){
        joinedStatus = NSLocalizedString(@"Invitation not yet accepted", nil);
    } else {
        if (group.iAmAdmin) {
            joinedStatus = NSLocalizedString(@"Admin", nil);
        }
        if (joinedMemberCount > 0) {
            if (joinedStatus.length>0) {
                joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
            }
            if (joinedMemberCount > 1) {
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@%d joined",nil), joinedStatus,joinedMemberCount];
            } else {
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@one joined",nil), joinedStatus];
            }
        } else {
            if (joinedStatus.length>0) {
                joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
            }
            joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@you are alone",nil), joinedStatus,joinedMemberCount];
            
        }
        if (invitedMemberCount > 0) {
            if (joinedStatus.length>0) {
                joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
            }
            joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@%d invited",nil), joinedStatus,invitedMemberCount];
        }
    }
    
    // cell.statusLabel.text = [NSString stringWithFormat:@"%@:%@",group.groupState,joinedStatus];
    // cell.statusLabel.text = [NSString stringWithFormat:@"%@:%@",group.groupState,group.clientId];
    cell.statusLabel.text = joinedStatus;
    
}

@end
