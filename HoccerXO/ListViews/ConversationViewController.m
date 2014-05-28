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
#import "GesturesInterpreter.h"
#import "SoundEffectPlayer.h"

#define TRACE_NOTIFICATIONS NO
#define FETCHED_RESULTS_DEBUG_PERF NO
#define NEARBY_CONFIG_DEBUG NO

@interface ConversationViewController ()

@property (strong) id catchObserver;
@property (strong) id messageObserver;
@property (strong) id loginObserver;
@property (strong) NSDate * catchDate;
@property (strong) HXOMessage * caughtMessage;
@property (strong) HXOMessage * lastMessage;
@property (strong) NSDate * lastMessageDate;

@property (strong) UIBarButtonItem * addButton;

@end


@implementation ConversationViewController

@dynamic inNearbyMode;

- (void)awakeFromNib {
    [super awakeFromNib];

    self.tabBarItem.image = [[[tab_chats alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"chat_list_nav_title", nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.addButton = self.navigationItem.rightBarButtonItem;
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

    if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: viewWillAppear, adding observers");

    self.catchObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"gesturesInterpreterDidDetectCatch"
                                                                           object:nil
                                                                            queue:[NSOperationQueue mainQueue]
                                                                       usingBlock:^(NSNotification *note) {
                                                                           if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: Catch");
                                                                           [SoundEffectPlayer catchDetected];
                                                                           const NSTimeInterval catchMessageBeforeGestureTime = 5.0;
                                                                           if (self.lastMessageDate != nil && [self.lastMessageDate timeIntervalSinceNow] > -catchMessageBeforeGestureTime) {
                                                                               // catch message that have arrived in the last 5 seconds before the gesture
                                                                               self.catchDate = nil;
                                                                               self.caughtMessage = self.lastMessage;
                                                                               [self performSegueWithIdentifier: @"showChat" sender: self];
                                                                           } else {
                                                                               self.catchDate = [NSDate new];
                                                                           }
                                                                           self.lastMessage = nil;
                                                                           self.lastMessageDate = nil;
                                                                       }];
    
    self.messageObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"receivedNewHXOMessage"
                                                                           object:nil
                                                                            queue:[NSOperationQueue mainQueue]
                                                                       usingBlock:^(NSNotification *note) {
                                                                           if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: Message received");
                                                                           NSDictionary * info = [note userInfo];
                                                                           HXOMessage * message = (HXOMessage *)info[@"message"];
                                                                           if (message != nil) {
                                                                               const NSTimeInterval catchMessageAfterGestureTime = 15.0;
                                                                               if (self.catchDate != nil && [self.catchDate timeIntervalSinceNow] > -catchMessageAfterGestureTime) {
                                                                                   // catch messages that arrive up to 15 sec after the catch gesture
                                                                                   self.catchDate = nil;
                                                                                   self.caughtMessage = message;
                                                                                   self.lastMessage = nil;
                                                                                   self.lastMessageDate = nil;
                                                                                   [self performSegueWithIdentifier: @"showChat" sender: self];
                                                                               } else {
                                                                                   self.lastMessage = message;
                                                                                   self.lastMessageDate = [NSDate new];
                                                                               }
                                                                           }

                                                                       }];
    self.loginObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"loginSucceeded"
                                                                             object:nil
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note) {
                                                                             if (TRACE_NOTIFICATIONS, YES) NSLog(@"ConversationView: loginSucceeded");
                                                                             [self configureForNearbyMode:self.inNearbyMode];
                                                                         }];

}

- (void) viewWillDisappear:(BOOL)animated {
    if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: viewWillDisappear, removing observers");
    if (self.catchObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.catchObserver];
    }
    if (self.messageObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.messageObserver];
    }
    if (self.loginObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.loginObserver];
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)configureForNearbyMode:(BOOL)mode {
    if (NEARBY_CONFIG_DEBUG) NSLog(@"ConversationViewController:configureForNearbyMode= %d", mode);
    [AppDelegate.instance configureForNearbyMode:mode];
    // hide plus button in nearby mode ... just for chrissy
    self.navigationItem.rightBarButtonItem = mode ? nil : self.addButton;
    
}

- (void) segmentChanged: (id) sender {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ConversationViewController:segmentChanged, sender= %@", sender);
    [super segmentChanged:sender];
    [self configureForNearbyMode:self.inNearbyMode];
}
    
#pragma mark - Table View

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier: @"showChat" sender: self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showChat"]) {
        if (self.caughtMessage == nil) {
            NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
            Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
            _chatViewController = [segue destinationViewController];
            _chatViewController.inspectedObject = contact;
        } else {
            _chatViewController = [segue destinationViewController];
            _chatViewController.inspectedObject = self.caughtMessage.contact;
            self.caughtMessage = nil;
        }
    }
}

- (void) addButtonPressed: (id) sender {
    [self invitePeople];
}

- (id) entityName {
    return [Contact entityName];
}

#pragma mark - Fetched results controller

- (NSArray*) sortDescriptors {
    if (!self.inNearbyMode) {
        return @[[[NSSortDescriptor alloc] initWithKey: @"latestMessageTime" ascending: NO],
                 [[NSSortDescriptor alloc] initWithKey: @"nickName" ascending: YES]];
    } else {
        return @[[[NSSortDescriptor alloc] initWithKey: @"type" ascending: NO],
                 [[NSSortDescriptor alloc] initWithKey: @"nickName" ascending: YES]];
    }
}

- (BOOL) inNearbyMode {
    return self.groupContactsToggle != nil && self.groupContactsToggle.selectedSegmentIndex == 1;
}

- (void) addPredicates: (NSMutableArray*) predicates {
    if (!self.inNearbyMode) {
        // Chats
        [predicates addObject: [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR relationshipState == 'kept' OR relationshipState == 'blocked' OR (type == 'Group' AND (myGroupMembership.state == 'joined' OR myGroupMembership.group.groupState == 'kept'))"]];
    } else {
        // NearBy
        //[predicates addObject: [NSPredicate predicateWithFormat: @"isNearbyTag == 'YES' OR (type == 'Group' AND (myGroupMembership.state == 'joined' AND myGroupMembership.group.groupType == 'nearby'))"]];
        [predicates addObject: [NSPredicate predicateWithFormat: @"(type == 'Contact' AND isNearbyTag == 'YES') OR (type == 'Group' AND (myGroupMembership.state == 'joined' AND myGroupMembership.group.groupType == 'nearby' AND myGroupMembership.group.groupState =='exists'))"]];
    }
}


- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString {
    // TODO: add full text search?
    [predicates addObject: [NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@", searchString]];
}

- (void)configureCell:(ConversationCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ConversationViewController:configureCell %@ path %@, self class = %@",  [cell class],indexPath, [self class]);
    if (cell == nil) {
        NSLog(@"%@:configureCell is nil, path %@",[self class], indexPath);
        NSLog(@"%@",[NSThread callStackSymbols]);
    }
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
