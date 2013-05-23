//
//  InviteGroupMemberViewController.m
//  HoccerXO
//
//  Created by David Siegel on 22.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupMemberInviteViewController.h"
#import "UIViewController+HXOSideMenuButtons.h"
#import "ContactCell.h"
#import "Contact.h"
#import "GroupMembership.h"
#import "HXOBackend.h"
#import "AppDelegate.h"

@interface GroupMemberInviteViewController ()
{
    Contact * _selectedContact;
}
@property (nonatomic, readonly) HXOBackend * chatBackend;

@end

@implementation GroupMemberInviteViewController

@synthesize chatBackend = _chatBackend;

- (void) setupNavigationBar {
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
}

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
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
    if ([self isContactMemberOfGroup: contact]) {
        cell.accessoryView = nil;
    } else {
        cell.accessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"navbar-icon-add"/*@"group_member_add"*/]];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];
    if ([self isContactMemberOfGroup:contact]) {
        return nil;
    }
    return indexPath;
}

- (BOOL) isContactMemberOfGroup: (Contact*) contact {
    NSSet * matching = [contact.groupMemberships objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        if ([[obj contact] isEqual: contact]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    if (matching.count == 0) {
        return NO;
    }
    return YES;
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
        [self.chatBackend inviteGroupMember:_selectedContact toGroup:self.group onDone:^(BOOL success) {
            // yeah
        }];
        //[self.navigationController popViewControllerAnimated: YES];
    }
}

@end
