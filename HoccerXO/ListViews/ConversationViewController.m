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
#import "Attachment.h"
#import "Environment.h"
#import "HXOUI.h"
#import "HXOLocalization.h"
#import "AvatarView.h"
#import "tab_chats.h"
#import "GesturesInterpreter.h"
#import "SoundEffectPlayer.h"
#import "DatasheetViewController.h"

#import "GroupMembership.h"
#import "HXOEnvironment.h"

#define TRACE_NOTIFICATIONS NO
#define FETCHED_RESULTS_DEBUG_PERF NO
#define NEARBY_CONFIG_DEBUG NO
#define SEGUE_DEBUG NO

//#define DEBUG_LATEST_MESSAGE

@interface ConversationViewController ()

@property (strong) id catchObserver;
@property (strong) id messageObserver;
@property (strong) id loginObserver;
@property (strong) id openMessageObserver;
@property (strong) id environmentGroupObserver;
@property (strong) id worldwideHiddenObserver;


@property (strong) NSDate * catchDate;
@property (strong) HXOMessage * caughtMessage;
@property (strong) HXOMessage * lastMessage;
@property (strong) NSDate * lastMessageDate;

@property (strong) HXOMessage * openedMessage;

@property (strong) UIBarButtonItem * addButton;

@end


@implementation ConversationViewController

@dynamic environmentMode;

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
    [HXOEnvironment.sharedInstance addObserver:self forKeyPath:@"groupId" options:0 context:nil];
    
    self.worldwideHiddenObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"WorldWideHiddenChanged"
                                                                                     object:nil
                                                                                      queue:[NSOperationQueue mainQueue]
                                                                                 usingBlock:^(NSNotification *note) {
                                                                                     if (TRACE_NOTIFICATIONS,1) NSLog(@"ConversationView: WorldWideHiddenChanged");
                                                                                     [self setupTitle];
                                                                                     [self segmentChanged:self];
                                                                                 }];
}

- (id) cellClass {
    return [ConversationCell class];
}

//- (void) setupTitle {
//    self.navigationItem.title = NSLocalizedString(@"chat_list_nav_title", nil);
//}

- (void) setupTitle {
    if (self.hasGroupContactToggle) {
        if (HXOEnvironment.worldwideHidden) {
            self.groupContactsToggle = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"chat_list_nav_title", nil), NSLocalizedString(@"nearby_list_nav_title", nil)]];

        } else {
            self.groupContactsToggle = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"chat_list_nav_title", nil), NSLocalizedString(@"nearby_list_nav_title", nil),NSLocalizedString(@"worldwide_list_nav_title", nil)]];
        }
        self.groupContactsToggle.selectedSegmentIndex = 0;
        [self.groupContactsToggle addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
        self.navigationItem.titleView = self.groupContactsToggle;
        [self updateSegmentDisabling];
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
    [self updateSegmentDisabling];

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
    
    self.messageObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kHXOReceivedNewHXOMessage
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
    
    self.openMessageObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"openHXOMessage"
                                                                                 object:nil
                                                                                  queue:[NSOperationQueue mainQueue]
                                                                             usingBlock:^(NSNotification *note) {
                                                                                 if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: openHXOMessage received");
                                                                                 NSDictionary * info = [note userInfo];
                                                                                 
                                                                                 NSString * messageId = info[@"messageId"];
                                                                                 if (messageId != nil) {
                                                                                     HXOMessage * message = [HXOBackend.instance getMessageById:messageId inContext:AppDelegate.instance.mainObjectContext];
                                                                                     if (message != nil) {
                                                                                         self.catchDate = nil;
                                                                                         self.openedMessage = message;
                                                                                         self.lastMessage = nil;
                                                                                         self.lastMessageDate = nil;
                                                                                         NSLog(@"openHXOMessage: show chat for message id=%@", messageId);
                                                                                         [self performSegueWithIdentifier: @"showChat" sender: self];
                                                                                     } else {
                                                                                         NSLog(@"openHXOMessage: message not found, id=%@", messageId);
                                                                                     }
                                                                                 } else {
                                                                                     NSLog(@"openHXOMessage: missing messageId in info=%@", info);
                                                                                 }
                                                                             }];
    self.loginObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"loginSucceeded"
                                                                           object:nil
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note) {
                                                                             if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: loginSucceeded");
                                                                             if (![self updateSegmentDisabling]) {
                                                                                 [self configureForMode:self.environmentMode];
                                                                             }
                                                                         }];
    
    self.environmentGroupObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"environmentGroupChanged"
                                                                           object:nil
                                                                            queue:[NSOperationQueue mainQueue]
                                                                       usingBlock:^(NSNotification *note) {
                                                                           if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: environmentChanged");
                                                                           [self updateFetchRequest];
                                                                       }];
    
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
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
    if (self.openMessageObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.openMessageObserver];
    }
    if (self.environmentGroupObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.environmentGroupObserver];
    }
    /*
    if (self.worldwideHiddenObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.worldwideHiddenObserver];
    }
     */

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual:HXOEnvironment.sharedInstance] && [keyPath isEqual:@"groupId"]) {
        if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: environment groupId changed to %@", HXOEnvironment.sharedInstance.groupId);
        [self updateFetchRequest];
    } else {
        if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
            [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)configureForMode:(EnvironmentActivationMode)mode {
    if (NEARBY_CONFIG_DEBUG) NSLog(@"ConversationViewController:configureForMode= %d", mode);
    [AppDelegate.instance configureForMode:mode];
    // hide plus button in nearby mode ... just for chrissy
    self.navigationItem.rightBarButtonItem = mode != ACTIVATION_MODE_NONE ? nil : self.addButton;
    
}

- (BOOL) updateSegmentDisabling {
    BOOL result = NO;
    if (self.environmentMode != ACTIVATION_MODE_NONE && HXOEnvironment.locationDenied) {
        // reset toggle to chats when location disabled
        if (self.groupContactsToggle.selectedSegmentIndex != 0) {
            self.groupContactsToggle.selectedSegmentIndex = 0;
            [self segmentChanged:self];
            result = YES;
        }
    }
    [self.groupContactsToggle setEnabled:!HXOEnvironment.locationDenied forSegmentAtIndex:1];
    if (!HXOEnvironment.worldwideHidden) {
        [self.groupContactsToggle setEnabled:!HXOEnvironment.locationDenied forSegmentAtIndex:2];
    }
    return result;
}

- (void) segmentChanged: (id) sender {
    if (FETCHED_RESULTS_DEBUG_PERF||NEARBY_CONFIG_DEBUG) NSLog(@"ConversationViewController:segmentChanged, sender= %@", sender);
    [super segmentChanged:sender];
    [self configureForMode:self.environmentMode];
    if (self.environmentMode == ACTIVATION_MODE_WORLDWIDE) {
        [self showFirstTimeWorldwideAlert];
    } else if (self.environmentMode == ACTIVATION_MODE_NEARBY) {
        [self showFirstTimeNearbyAlert];
    }
}

// main context only
- (void) showFirstTimeWorldwideAlert {        
    
    BOOL dialogShown = [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOWorldwideDialogShown]];
    if (dialogShown) {
        return;
    }
    
    
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"chat_worldwide_intro_message",nil)];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"chat_worldwide_intro_title", nil)
                                                     message: NSLocalizedString(message, nil)
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 unsigned long worldwide_delay = 0;
                                                 switch (buttonIndex) {
                                                     case 0: {
                                                         // 0 min
                                                         worldwide_delay = 0;
                                                     }
                                                         break;
                                                     case 1: {
                                                         // 60 min
                                                         worldwide_delay = 60 * 60;
                                                     }
                                                         break;
                                                     case 2:
                                                         // 6 hours
                                                         worldwide_delay = 60 * 60 * 6;
                                                         break;
                                                 }

                                                 [[HXOUserDefaults standardUserDefaults] setValue:[NSNumber numberWithUnsignedLong:worldwide_delay] forKey:kHXOWorldwideTimeToLive];
                                                 [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOWorldwideDialogShown]];
                                             }
                                           cancelButtonTitle: nil
                                           otherButtonTitles: NSLocalizedString(@"chat_worldwide_intro_0_min", nil), NSLocalizedString(@"chat_worldwide_intro_1_hour", nil), NSLocalizedString(@"chat_worldwide_intro_6_hours", nil),nil];

    [alert show];
}

// main context only
- (void) showFirstTimeNearbyAlert {
    
    BOOL dialogShown = [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXONearbyDialogShown]];
    if (dialogShown) {
        return;
    }
    
    
    NSString * message = [NSString stringWithFormat: NSLocalizedString(@"chat_nearby_intro_message",nil)];
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"chat_nearby_intro_title", nil)
                                                     message: NSLocalizedString(message, nil)
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXONearbyDialogShown]];
                                             }
                                           cancelButtonTitle: nil
                                           otherButtonTitles: NSLocalizedString(@"ok", nil),nil];
    [alert show];
}


#pragma mark - Table View

- (NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // prevent double triggering the transition in didSelectRowAtIndexPath by
    // guarding against duplicate selection of the same row.
    return [[tableView indexPathForSelectedRow] isEqual: indexPath] ? nil : indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier: @"showChat" sender: indexPath];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id) sender {
    if (SEGUE_DEBUG) NSLog(@"ConversationViewController:prepareForSegue: %@", segue.identifier);
    if ([sender isKindOfClass:[NSIndexPath class]]) {
        
        NSIndexPath * indexPath = (NSIndexPath *)sender;
        Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
        
        if ([segue.identifier isEqualToString:@"showChat"]) {
            _chatViewController = [segue destinationViewController];
            _chatViewController.inspectedObject = contact;
            
        } else if ([segue.identifier isEqualToString:@"showContact"] || [segue.identifier isEqualToString: @"showGroup"]) {
            ((DatasheetViewController*)segue.destinationViewController).inspectedObject = contact;
        }
    } else if ([segue.identifier isEqualToString:@"showChat"] && self.openedMessage != nil) {
        _chatViewController = [segue destinationViewController];
        _chatViewController.inspectedObject = self.openedMessage.contact;
        self.openedMessage = nil;
    } else if ([segue.identifier isEqualToString:@"showChat"] && self.caughtMessage != nil) {
            _chatViewController = [segue destinationViewController];
            _chatViewController.inspectedObject = self.caughtMessage.contact;
            self.caughtMessage = nil;
    } else {
        [super prepareForSegue: segue sender: sender];
    }
}

- (IBAction) unwindToRootView: (UIStoryboardSegue*) unwindSegue {
    if (SEGUE_DEBUG) NSLog(@"ConversationViewController:unwindToRootView src=%@ dest=%@", [unwindSegue.sourceViewController class], [unwindSegue.destinationViewController class]);
    if ([unwindSegue.sourceViewController respondsToSelector:@selector(setInspectedObject:)]) {
        [unwindSegue.sourceViewController performSelector:@selector(setInspectedObject:) withObject:nil];
    }
}

- (void) addButtonPressed: (id) sender {
    [self invitePeople];
}

- (id) entityName {
    return [Contact entityName];
}

- (void) contactCellDidPressAvatar:(ContactCell *)cell {
    NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
    Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath: indexPath];

    [self performSegueWithIdentifier: contact.isGroup ? @"showGroup" : @"showContact" sender: indexPath];
}

#pragma mark - Fetched results controller

- (NSArray*) sortDescriptors {
    if (self.environmentMode == ACTIVATION_MODE_NONE) {
        return @[[[NSSortDescriptor alloc] initWithKey: @"latestMessageTime" ascending: NO],
                 [[NSSortDescriptor alloc] initWithKey: @"nickName" ascending: YES]];
    } else {
        return @[[[NSSortDescriptor alloc] initWithKey: @"type" ascending: NO],
                 [[NSSortDescriptor alloc] initWithKey: @"nickName" ascending: YES]];
    }
}

- (EnvironmentActivationMode) environmentMode {
    if (self.groupContactsToggle != nil) {
        if (self.groupContactsToggle.selectedSegmentIndex == 1) {
            return ACTIVATION_MODE_NEARBY;
        } else if (self.groupContactsToggle.selectedSegmentIndex == 2) {
            return ACTIVATION_MODE_WORLDWIDE;
        }
    };
    return ACTIVATION_MODE_NONE;
}

- (void) addPredicates: (NSMutableArray*) predicates {
    if (self.environmentMode == ACTIVATION_MODE_NEARBY) {
        [predicates addObject: [NSPredicate predicateWithFormat:
                                @"(type == 'Contact' AND \
                                SUBQUERY(groupMemberships, $member, $member.group.groupType == 'nearby' AND $member.group.groupState =='exists').@count > 0 ) \
                                OR \
                                (type == 'Group' AND \
                                (myGroupMembership.state == 'joined' AND \
                                myGroupMembership.group.groupType == 'nearby' AND \
                                myGroupMembership.group.groupState =='exists' AND\
                                SUBQUERY(myGroupMembership.group.members, $member, $member.role == 'nearbyMember').@count > 1 ))"]];
    } else if (self.environmentMode == ACTIVATION_MODE_WORLDWIDE) {
        NSString * myWorldWideGroupId = HXOEnvironment.sharedInstance.groupId;
        if (myWorldWideGroupId == nil) {
            myWorldWideGroupId = @"no-environment-group";
        }
        if (NEARBY_CONFIG_DEBUG) NSLog(@"addPredicates: myWorldWideGroupId=%@", myWorldWideGroupId);
        [predicates addObject: [NSPredicate predicateWithFormat:
                                @"(type == 'Contact' AND \
                                    SUBQUERY(groupMemberships, $member, \
                                        $member.group.clientId == %@ AND \
                                        $member.state == 'joined' AND \
                                        $member.group.groupType == 'worldwide' AND \
                                        $member.group.groupState =='exists').@count > 0 ) \
                                OR \
                                (type == 'Group' AND \
                                ((myGroupMembership.state == 'joined' OR myGroupMembership.state == 'suspended') AND \
                                    myGroupMembership.group.groupType == 'worldwide' AND \
                                    myGroupMembership.group.groupState =='exists' AND\
                                    SUBQUERY(myGroupMembership.group.members, $member, $member.role == 'worldwideMember' AND $member.state == 'joined').@count > 1 ))",myWorldWideGroupId]];
    } else {
        [predicates addObject: [NSPredicate predicateWithFormat:
                                @"relationshipState == 'friend' OR \
                                   ((relationshipState == 'kept' OR relationshipState == 'blocked') AND messages.@count > 0) OR \
                                (type == 'Group' AND \
                                    (myGroupMembership.state == 'joined' OR \
                                        myGroupMembership.state == 'suspended' OR \
                                        myGroupMembership.group.groupState == 'kept')) OR \
                                (type == 'Contact' AND \
                                    SUBQUERY(groupMemberships, $member, \
                                    $member.state != 'suspended' AND \
                                    $member.group.groupType == 'worldwide' AND \
                                    $member.group.groupState =='exists').@count > 0 )"]];
    }
}

// will return localized strings of theDate depending on how long it is ago:
// if theDate is tody, only the time will be returned
// if theDate is this year, only day and month will be returned
// otherwise, day, month and year in short format will be returned

- (NSString*)adaptiveDateTimeString:(NSDate*)theDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:[NSDate date]];
    NSDate *today = [calendar dateFromComponents:components];
    components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit) fromDate:[NSDate date]];
    NSDate *thisYear = [calendar dateFromComponents:components];
    
    components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate: theDate];
    NSDate *latestMessageDate = [calendar dateFromComponents:components];
    
    components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit) fromDate: theDate];
    NSDate *latestMessageYear = [calendar dateFromComponents:components];
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    if([today isEqualToDate: latestMessageDate]) {
        // show only the time
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    } else if([thisYear isEqualToDate: latestMessageYear]){
        // show month and day
        NSLocale *currentLocale = [NSLocale currentLocale];
        
        // the date components we want
        NSString *dateComponents = @"Md";
        
        // The components will be reordered according to the locale
        NSString *dateFormat = [NSDateFormatter dateFormatFromTemplate:dateComponents options:0 locale:currentLocale];
        //NSLog(@"Date format for %@: %@", [currentLocale displayNameForKey:NSLocaleIdentifier value:[currentLocale localeIdentifier]], dateFormat);
        
        [formatter setTimeStyle:NSDateFormatterNoStyle];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setDateFormat:dateFormat];
    } else {
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
    }
    return [formatter stringFromDate: theDate];
}

#ifdef DEBUG_LATEST_MESSAGE


- (HXOMessage*)latestMessageForContact:(Contact*)contact {
    NSFetchRequest *fetchRequest = [NSFetchRequest new];
    NSEntityDescription *entity = [NSEntityDescription entityForName:[HXOMessage entityName] inManagedObjectContext:AppDelegate.instance.mainObjectContext];
    [fetchRequest setEntity:entity];
    
    //NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(contact == %@) AND (timeAccepted == contact.latestMessageTime)", contact];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"contact == %@", contact];
    [fetchRequest setPredicate: predicate];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeAccepted" ascending: NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];

    NSError *error = nil;
    NSArray *array = [AppDelegate.instance.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (array.count > 0) {
        return array[0];
    }
    return nil;
}

/*
 
 This is a reminder because bugs concerning missing latest messages seem
 to reappear from time to time.
 
 When the latest message does not appear in the cell for group messages,
 then the cause is probably not here, but in the backend code.
 
 Typically the reason is that message.timeAccepted does not match
 contact.lastMessageTime because one of them has not been properly
 set after acceptedTime in Delivery has been sent by the server.
 
 The debug code above and below can be used to find out which value
 is wrong by comparing the millis with those that came over the wire.
 
*/

#endif


- (void)configureCell:(ConversationCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ConversationViewController:configureCell %@ path %@, self class = %@",  [cell class],indexPath, [self class]);
    if (cell == nil) {
        NSLog(@"%@:configureCell is nil, path %@",[self class], indexPath);
        NSLog(@"%@",[NSThread callStackSymbols]);
    }
    [super configureCell: cell atIndexPath: indexPath];
    Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];

#ifdef DEBUG_LATEST_MESSAGE
    NSLog(@"contact class %@ nick %@, latestCount=%lu group.latestMessageTime=%@ millis=%@", contact.class, contact.nickName, (unsigned long)contact.latestMessage.count, contact.latestMessageTime, [HXOBackend millisFromDate:contact.latestMessageTime]);
    
    HXOMessage * myLatestMessage = [self latestMessageForContact:contact];
    NSLog(@"myLatestMessage: %@ %@, millis=%@", myLatestMessage.body, myLatestMessage.timeAccepted, [HXOBackend millisFromDate:myLatestMessage.timeAccepted]);
    
    
    NSSet * memberships = contact.groupMemberships;
    for (GroupMembership * membership in memberships) {
        NSLog(@"member in group %@", membership.group);
        
    }
    
#endif
    
    cell.delegate = self;
    cell.avatar.badgeText = [HXOUI messageCountBadgeText: contact.unreadMessages.count];

    NSDate * latestMessageTime = nil;
    if ([contact.latestMessage count] == 0){
        cell.subtitleLabel.text = nil;
    } else {
        HXOMessage * message = contact.latestMessage[0];
        if (message.body.length > 0) {
            cell.subtitleLabel.text = message.body;
        } else {
            if (message.attachment != nil) {
                NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", message.attachment.mediaType];
                cell.subtitleLabel.text = [NSString stringWithFormat:@"[%@]", NSLocalizedString(attachment_type,nil)];
            } else {
                // can happen if the latest message has been deleted
                cell.subtitleLabel.text = nil;
            }
        }
        latestMessageTime = message.timeAccepted;
        //NSLog(@"--- contact class %@ nick %@, latestDate=%@", contact.class, contact.nickName, message.timeAccepted);
    }

    if (latestMessageTime) {
        cell.dateLabel.text = [self adaptiveDateTimeString:latestMessageTime];
    } else {
        cell.dateLabel.text = @"";
    }


    //[cell setNeedsLayout];
}

#pragma mark - Empty Table Placeholder

- (NSAttributedString*) placeholderText {
    if (self.environmentMode == ACTIVATION_MODE_NONE) {
        return HXOLocalizedStringWithLinks(@"contact_list_placeholder", nil);
    } else if (self.environmentMode == ACTIVATION_MODE_NEARBY) {
        return HXOLocalizedStringWithLinks(@"contact_list_placeholder_nearby", nil);
    } else if (self.environmentMode == ACTIVATION_MODE_WORLDWIDE) {
        return HXOLocalizedStringWithLinks(@"contact_list_placeholder_worldwide", nil);
    } else {
        NSLog(@"illegal environment mode %d", self.environmentMode);
        return nil;
    }
}

- (UIImage*) placeholderImage {
    if (self.environmentMode == ACTIVATION_MODE_NONE) {
        return [UIImage imageNamed: @"placeholder-chats"];
    } else if (self.environmentMode == ACTIVATION_MODE_NEARBY) {
        return [UIImage imageNamed: @"placeholder-nearby"];
    } else if (self.environmentMode == ACTIVATION_MODE_WORLDWIDE) {
        return [UIImage imageNamed: @"placeholder-world"];
    } else {
        NSLog(@"illegal environment mode %d", self.environmentMode);
        return nil;
    }
}

- (SEL) placeholderAction {
    return self.environmentMode != ACTIVATION_MODE_NONE ? NULL : @selector(addButtonPressed:);
}

@end
