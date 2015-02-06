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

#define TRACE_NOTIFICATIONS NO
#define FETCHED_RESULTS_DEBUG_PERF NO
#define NEARBY_CONFIG_DEBUG NO
#define SEGUE_DEBUG NO

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
                                                                             if (TRACE_NOTIFICATIONS) NSLog(@"ConversationView: loginSucceeded");
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
    if (self.inNearbyMode) {
        [predicates addObject: [NSPredicate predicateWithFormat:
                                @"(type == 'Contact' AND \
                                SUBQUERY(groupMemberships, $member, $member.group.groupType == 'nearby' AND $member.group.groupState =='exists').@count > 0 ) \
                                OR \
                                (type == 'Group' AND \
                                (myGroupMembership.state == 'joined' AND \
                                myGroupMembership.group.groupType == 'nearby' AND \
                                myGroupMembership.group.groupState =='exists' AND\
                                SUBQUERY(myGroupMembership.group.members, $member, $member.role == 'nearbyMember').@count > 1 ))"]];
    } else {
        [predicates addObject: [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR (relationshipState == 'kept' AND messages.@count > 0) OR relationshipState == 'blocked' OR (type == 'Group' AND (myGroupMembership.state == 'joined' OR myGroupMembership.group.groupState == 'kept'))"]];
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
    NSLog(@"contact class %@ nick %@, latestCount=%d group.latestMessageTime=%@ millis=%@", contact.class, contact.nickName, contact.latestMessage.count, contact.latestMessageTime, [HXOBackend millisFromDate:contact.latestMessageTime]);
    
    HXOMessage * myLatestMessage = [self latestMessageForContact:contact];
    NSLog(@"myLatestMessage: %@ %@, millis=%@", myLatestMessage.body, myLatestMessage.timeAccepted, [HXOBackend millisFromDate:myLatestMessage.timeAccepted]);
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
    return HXOLocalizedStringWithLinks(self.inNearbyMode ? @"contact_list_placeholder_nearby" : @"contact_list_placeholder", nil);
}

- (UIImage*) placeholderImage {
    return [UIImage imageNamed: self.inNearbyMode ? @"placeholder-nearby" : @"placeholder-chats"];
}

- (SEL) placeholderAction {
    return self.inNearbyMode ? NULL : @selector(addButtonPressed:);
}

@end
