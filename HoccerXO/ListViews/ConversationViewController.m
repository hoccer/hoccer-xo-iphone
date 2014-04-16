//
//  MasterViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "ChatViewController.h"
#import "Contact.h"
#import "ConversationCell.h"
#import "HXOMessage.h"
#import "AppDelegate.h"
#import "HXOUserDefaults.h"
#import "ProfileViewController.h"
#import "Attachment.h"
#import "Environment.h"
#import "HXOUI.h"
#import "AvatarView.h"
#import "tab_chats.h"
#import "HXOEnvironment.h"

@implementation ConversationViewController

- (void)awakeFromNib {
    [super awakeFromNib];

    self.tabBarItem.image = [[[tab_chats alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"chat_list_nav_title", nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

- (id) cellClass {
    return [ConversationCell class];
}

//- (void) setupTitle {
//    self.navigationItem.title = NSLocalizedString(@"chat_list_nav_title", nil);
//}

- (void) setupTitle {
    if (self.hasGroupContactToggle) {
        self.groupContactsToggle = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"chat_list_nav_title", nil), NSLocalizedString(@"nearby_list_nav_title", nil)]];
        self.groupContactsToggle.selectedSegmentIndex = 0;
        [self.groupContactsToggle addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
        self.navigationItem.titleView = self.groupContactsToggle;
    }
    self.navigationItem.title = NSLocalizedString(@"chat_list_nav_title", nil);
}

- (ChatViewController*) chatViewController {
    if (_chatViewController == nil) {
        _chatViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"chatViewController"];
    }
    return _chatViewController;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [HXOBackend broadcastConnectionInfo];

    [AppDelegate setWhiteFontStatusbarForViewController:self];

}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    /*
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
        UINavigationController * profileView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalProfileNavigationController"];
        [self.navigationController presentViewController: profileView animated: YES completion: nil];
    }
     */
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) segmentChanged: (id) sender {
    [super segmentChanged:sender];
    [HXOEnvironment.sharedInstance setActivation:(self.groupContactsToggle.selectedSegmentIndex == 1)];
}
    
#pragma mark - Table View

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier: @"showChat" sender: self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showChat"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
        _chatViewController = [segue destinationViewController];
        _chatViewController.inspectedObject = contact;
    }
}

- (void) addButtonPressed: (id) sender {
    if (self.groupContactsToggle && self.groupContactsToggle.selectedSegmentIndex == 1) {
        // [self performSegueWithIdentifier: @"showGroup" sender: sender];
    } else {
        [self invitePeople];
    }
}

- (id) entityName {
    return [Contact entityName];
}

#pragma mark - Fetched results controller

- (NSArray*) sortDescriptors {
    return @[[[NSSortDescriptor alloc] initWithKey: @"latestMessageTime" ascending: NO],
             [[NSSortDescriptor alloc] initWithKey: @"nickName" ascending: YES]];
}

- (void) addPredicates: (NSMutableArray*) predicates {
    if (self.groupContactsToggle.selectedSegmentIndex == 0) {
        // Chats
    [predicates addObject: [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR relationshipState == 'kept' OR relationshipState == 'blocked' OR (type == 'Group' AND (myGroupMembership.state == 'joined' OR myGroupMembership.group.groupState == 'kept'))"]];
    } else {
        // NearBy
        [predicates addObject: [NSPredicate predicateWithFormat: @"isNearby == 'YES' OR (type == 'Group' AND (myGroupMembership.state == 'joined' AND myGroupMembership.group.groupType == 'nearby'))"]];
    }
}


- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString {
    // TODO: add full text search?
    [predicates addObject: [NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@", searchString]];
}

- (void)configureCell:(ConversationCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    [super configureCell: cell atIndexPath: indexPath];
    Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];

    cell.avatar.badgeText = [HXOUI messageCountBadgeText: contact.unreadMessages.count];

    // XXX TODO: cell.avatar.showLed = NO;
    
    NSDate * latestMessageTime = nil;
    if ([contact.latestMessage count] == 0){
        cell.subtitleLabel.text = nil;
    } else {
        HXOMessage * message = contact.latestMessage[0];
        if (message.body.length > 0) {
            cell.subtitleLabel.text = message.body;
            // TODO: do not mess with the fonts
            //cell.subtitleLabel.font = [UIFont systemFontOfSize: cell.subtitleLabel.font.pointSize];
        } else {
            if (message.attachment != nil) {
                NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", message.attachment.mediaType];
                cell.subtitleLabel.text = [NSString stringWithFormat:@"[%@]", NSLocalizedString(attachment_type,nil)];
            } else {
                cell.subtitleLabel.text = @"<>"; // should never happen
            }
            // TODO: do not mess with the fonts
            //cell.subtitleLabel.font = [UIFont italicSystemFontOfSize: cell.subtitleLabel.font.pointSize];
        }
        latestMessageTime = message.timeAccepted;
    }

    if (latestMessageTime) {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:[NSDate date]];
        NSDate *today = [calendar dateFromComponents:components];

        components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate: latestMessageTime];
        NSDate *latestMessageDate = [calendar dateFromComponents:components];
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        if([today isEqualToDate: latestMessageDate]) {
            [formatter setDateStyle:NSDateFormatterNoStyle];
            [formatter setTimeStyle:NSDateFormatterShortStyle];
        } else {
            [formatter setDateStyle:NSDateFormatterMediumStyle];
            [formatter setTimeStyle:NSDateFormatterNoStyle];
        }
        cell.dateLabel.text = [formatter stringFromDate: latestMessageTime];
    } else {
        cell.dateLabel.text = @"";
    }


    //[cell setNeedsLayout];
}

@end
