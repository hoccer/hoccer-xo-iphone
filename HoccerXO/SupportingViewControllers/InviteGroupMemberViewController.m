//
//  InviteGroupMemberViewController.m
//  HoccerXO
//
//  Created by David Siegel on 22.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InviteGroupMemberViewController.h"
#import "UIViewController+HXOSideMenuButtons.h"
#import "ContactCell.h"
#import "Contact.h"
#import "GroupMembership.h"

@interface InviteGroupMemberViewController ()
{
    Contact * _selectedContact;
}
@end

@implementation InviteGroupMemberViewController

- (void) setupNavigationBar {
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
}

- (void) setGroup:(Group *)group {
    _group = group;
    [self clearFetchedResultsControllers];
}

- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)cell
                     atIndexPath:(NSIndexPath *)indexPath
{
    [super fetchedResultsController: fetchedResultsController configureCell:cell atIndexPath: indexPath];
    Contact * contact = (Contact*)[fetchedResultsController objectAtIndexPath:indexPath];
    NSSet * matching = [contact.groupMemberships objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        if ([[obj contact] isEqual: contact]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    if (matching.count == 0) {
        cell.accessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"navbar-icon-add"/*@"group_member_add"*/]];
    } else {
        cell.accessoryView = nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    _selectedContact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];
    NSString * title = [NSString stringWithFormat: NSLocalizedString(@"group_invite_title", nil), _selectedContact.nickName, self.group.nickName];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                     message: nil
                                                    delegate: self
                                           cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                           otherButtonTitles:NSLocalizedString(@"Ok", nil), nil];
    [alert show];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != alertView.cancelButtonIndex) {
        NSLog(@"GroupMemberInviteViewController: TODO: invite %@ to group %@", _selectedContact.nickName, self.group.nickName);
        //[self.navigationController popViewControllerAnimated: YES];
    }
}

@end
