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
#import "InvitationController.h"
#import "Attachment.h"
#import "Environment.h"
#import "HXOTheme.h"

//#define HIDE_SEPARATORS

@interface ConversationViewController ()

@property (nonatomic,readonly) ConversationCell * conversationCell;

@end

@implementation ConversationViewController

- (void)awakeFromNib {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}

- (ConversationCell*) conversationCell {
    return (ConversationCell*)[self prototypeCellOfClass: [ConversationCell class]];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [ConversationCell class]];
    
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"back_button_title", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

}


- (UITableViewCell*) prototypeCell {
    return [self prototypeCellOfClass: [ConversationCell class]];
}

- (void) setupTitle {
    self.navigationItem.title = NSLocalizedString(@"Chats", nil);
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

    // TODO: find a way to move this to the app delegate
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
        UINavigationController * profileView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalProfileNavigationController"];
        [self.navigationController presentViewController: profileView animated: YES completion: nil];
    }
    // [AppDelegate setDefaultAudioSession]; // should be removed when a better AudioPlayer is in Place; right now we set the default mode here in case an Audio has been played and the MusicSession has been enabled
    //self.view.userInteractionEnabled = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table View


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        return 0;
    }
    return [[self.currentFetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        return 0;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.currentFetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactCell * cell = (ContactCell*)[self dequeueReusableCellOfClass: [ConversationCell class] forIndexPath: indexPath];
    [self fetchedResultsController: self.currentFetchedResultsController configureCell: cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];
        self.chatViewController.partner = contact;
    }
    
    [self performSegueWithIdentifier: @"showChat" sender: self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showChat"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
        _chatViewController = [segue destinationViewController];
        _chatViewController.inspectedObject = contact;
    }
}

#pragma mark - Fetched results controller

- (NSArray*) sortDescriptors {
    return @[[[NSSortDescriptor alloc] initWithKey: @"latestMessageTime" ascending: NO],
             [[NSSortDescriptor alloc] initWithKey: @"nickName" ascending: YES]];
}

- (void) addPredicates: (NSMutableArray*) predicates {
    // TODO: This looks suspiciously similar to the predicate used in ContactListViewController. Review!
    [predicates addObject: [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR relationshipState == 'kept' OR relationshipState == 'blocked' OR (type == 'Group' AND (myGroupMembership.state == 'joined' OR myGroupMembership.group.groupState == 'kept'))"]];
}

- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString {
    // TODO: add full text search?
    [predicates addObject: [NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@", searchString]];
}

- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)aCell
                     atIndexPath:(NSIndexPath *)indexPath
{
    [super fetchedResultsController: fetchedResultsController configureCell: aCell atIndexPath: indexPath];

    //NSLog(@"Conv configureCell atIndexPath=%@",indexPath);
    ConversationCell * cell = (ConversationCell*)aCell;
    Contact * contact = (Contact*)[fetchedResultsController objectAtIndexPath:indexPath];

    cell.avatar.showLed = NO;
    
    NSDate * latestMessageTime = nil;
    if ([contact.latestMessage count] == 0){
        cell.subtitleLabel.text = nil;
    } else {
        HXOMessage * message = contact.latestMessage[0];
        if (message.body.length > 0) {
            cell.subtitleLabel.text = message.body;
            // TODO: do not mess with the fonts
            cell.subtitleLabel.font = [UIFont systemFontOfSize: cell.subtitleLabel.font.pointSize];
        } else {
            if (message.attachment != nil) {
                cell.subtitleLabel.text = [NSString stringWithFormat:@"[%@]", NSLocalizedString(message.attachment.mediaType,nil)];
            } else {
                cell.subtitleLabel.text = @"<>"; // should never happen
            }
            // TODO: do not mess with the fonts
            cell.subtitleLabel.font = [UIFont italicSystemFontOfSize: cell.subtitleLabel.font.pointSize];
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

    NSUInteger unreadCount = contact.unreadMessages.count;
    // NSLog(@"Conv unreadCount=%d",unreadCount);
    cell.hasNewMessages = unreadCount > 0;
/*
    cell.unreadMessageCountLabel.hidden = unreadCount == 0;
    cell.unreadMessageCountLabel.text = unreadCount > 99 ? @">99" : [@(unreadCount) stringValue];
    CGRect frame = cell.unreadMessageCountLabel.bounds;
    CGFloat oldWidth = frame.size.width;
    [cell.unreadMessageCountLabel sizeToFit];
    CGFloat dx = oldWidth - cell.unreadMessageCountLabel.frame.size.width;
    frame = cell.unreadMessageCountLabel.frame;
    frame.origin.x += dx;
    cell.unreadMessageCountLabel.frame = frame;
 */

    [cell setNeedsLayout];
}


@end
