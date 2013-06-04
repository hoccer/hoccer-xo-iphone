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
#import "InsetImageView.h"
#import "AssetStore.h"
#import "HXOMessage.h"
#import "MFSideMenu.h"
#import "AppDelegate.h"
#import "UIViewController+HXOSideMenuButtons.h"
#import "HXOUserDefaults.h"
#import "RadialGradientView.h"
#import "CustomNavigationBar.h"
#import "ProfileViewController.h"
#import "InviteCell.h"
#import "InvitationController.h"
#import "Attachment.h"
#import "Environment.h"

@interface ConversationViewController ()

@property (nonatomic,strong) ConversationCell * conversationCell;
@property (nonatomic,strong) InviteCell       * inviteCell;

@property (strong, nonatomic) id connectionInfoObserver;


- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation ConversationViewController

- (void)awakeFromNib {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    self.conversationCell = [self.tableView dequeueReusableCellWithIdentifier: [ConversationCell reuseIdentifier]];

    UINib * nib = [UINib nibWithNibName: @"InviteCell" bundle: [NSBundle mainBundle]];
    [self.tableView registerNib: nib forCellReuseIdentifier: [InviteCell reuseIdentifier]];
    self.inviteCell = [self.tableView dequeueReusableCellWithIdentifier: [InviteCell reuseIdentifier]];

    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];

    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }

    UIImage * icon = [UIImage imageNamed: @"navbar-icon-home"];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage: icon style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"navbar_logo"]];

    // TODO: ask @zutrinken
    self.tableView.backgroundView = [[RadialGradientView alloc] initWithFrame: self.tableView.frame];
    
    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];
}

- (ChatViewController*) chatViewController {
    if (_chatViewController == nil) {
        _chatViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"chatViewController"];
    }
    return _chatViewController;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
    [HXOBackend broadcastConnectionInfo];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];

    // TODO: find a way to move this to the app delegate
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
        UINavigationController * profileView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalProfileViewController"];
        [self.navigationController presentViewController: profileView animated: YES completion: nil];
    }
    // [AppDelegate setDefaultAudioSession]; // should be removed when a better AudioPlayer is in Place; right now we set the default mode here in case an Audio has been played and the MusicSession has been enabled
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table View

- (BOOL) isEmpty {
    if (self.fetchedResultsController.sections.count == 0) {
        return YES;
    } else if (self.fetchedResultsController.sections.count == 1) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][0];
        return [sectionInfo numberOfObjects] == 0;
    }
    return NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count;
    if (self.emptyTablePlaceholder != nil) {
        count = 1;
    } else {
        count = [[self.fetchedResultsController sections] count];
    }
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count;
    if (self.emptyTablePlaceholder != nil) {
        count = 1;
    } else {
        id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
        count = [sectionInfo numberOfObjects];
    }
    return count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.emptyTablePlaceholder) {
        self.emptyTablePlaceholder.placeholder.text = NSLocalizedString(@"conversation_empty_placeholder", nil);
        self.emptyTablePlaceholder.icon.image = [UIImage imageNamed: @"xo.png"];
        return self.emptyTablePlaceholder;
    } else if ([self isLastCell: indexPath]) {
        InviteCell * cell = [tableView dequeueReusableCellWithIdentifier: [InviteCell reuseIdentifier] forIndexPath: indexPath];
        [cell.button addTarget: self action: @selector(inviteFriendsPressed:) forControlEvents: UIControlEventTouchUpInside];
        return cell;
    } else {
        UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier: [ConversationCell reuseIdentifier] forIndexPath: indexPath];
        [self configureCell:cell atIndexPath:indexPath];
        return cell;
    }
}

- (BOOL) isLastCell: (NSIndexPath*) indexPath {
    return indexPath.section == [self numberOfSectionsInTableView: self.tableView] - 1 && indexPath.row == [self tableView: self.tableView numberOfRowsInSection: indexPath.section] - 1;
}

- (void) inviteFriendsPressed: (id) sender {
    [[InvitationController sharedInvitationController] presentWithViewController: self];
}

- (CGFloat) tableView: (UITableView*) tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.emptyTablePlaceholder && indexPath.row == 0) {
        return self.emptyTablePlaceholder.bounds.size.height;
    } else if ([self isLastCell: indexPath]) {
        return self.inviteCell.bounds.size.height;
    } else {
        return self.conversationCell.bounds.size.height;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        Contact * contact = (Contact*)[[self fetchedResultsController] objectAtIndexPath:indexPath];
        self.chatViewController.partner = contact;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showChat"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Contact * contact = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        _chatViewController = [segue destinationViewController];
        [_chatViewController setPartner: contact];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName: [Contact entityName] inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    // performance: do not include subentities
    //fetchRequest.includesSubentities = NO;
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"latestMessageTime" ascending: NO];
    NSArray *sortDescriptors = @[sortDescriptor];

    [fetchRequest setSortDescriptors:sortDescriptors];

    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR (type == 'Group' AND myGroupMembership.state == 'joined')"];
    [fetchRequest setPredicate: filterPredicate];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    //NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Contacts"];
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil]; // fetchrequest will not reflect changes in the filter during development when cached
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
   switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            /* workaround - see:
             * http://stackoverflow.com/questions/14354315/simultaneous-move-and-update-of-uitableviewcell-and-nsfetchedresultscontroller
             * and
             * http://developer.apple.com/library/ios/#releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/
             */
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:newIndexPath ? newIndexPath : indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }

    [self updateEmptyTablePlaceholderAnimated: YES];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)aCell atIndexPath:(NSIndexPath *)indexPath {
    ConversationCell * cell = (ConversationCell*)aCell;
    Contact * contact = (Contact*)[self.fetchedResultsController objectAtIndexPath:indexPath];
    // cell.nickName.text = contact.nickName;
    cell.nickName.text = contact.nickNameWithStatus;
    UIImage * avatar = contact.avatarImage;
    if (avatar == nil) {
        NSString * avatarName = [contact.type isEqualToString: @"Group"] ?  @"avatar_default_group" : @"avatar_default_contact";
        avatar = [UIImage imageNamed: avatarName];
    }
    cell.avatar.image = avatar;
    cell.latestMessageLabel.frame = self.conversationCell.latestMessageLabel.frame;
    NSDate * latestMessageTime = nil;
    if ([contact.latestMessage count] == 0){
        cell.latestMessageLabel.text = NSLocalizedString(@"no_messages_exchanged", nil);
        cell.latestMessageLabel.font = [UIFont italicSystemFontOfSize: cell.latestMessageLabel.font.pointSize];
        cell.latestMessageDirection.image = nil;
    } else {
        HXOMessage * message = contact.latestMessage[0];
        if (message.body.length > 0) {
            cell.latestMessageLabel.text = message.body;            
            cell.latestMessageLabel.font = [UIFont systemFontOfSize: cell.latestMessageLabel.font.pointSize];
        } else {
            if (message.attachment != nil) {
                cell.latestMessageLabel.text = [NSString stringWithFormat:@"[%@]", NSLocalizedString(message.attachment.mediaType,nil)];
            } else {
                cell.latestMessageLabel.text = @"<>"; // should never happen
            }
            cell.latestMessageLabel.font = [UIFont italicSystemFontOfSize: cell.latestMessageLabel.font.pointSize];
        }
        latestMessageTime = message.timeAccepted;
        if ([message.isOutgoing boolValue] == YES) {
            cell.latestMessageDirection.image = [UIImage imageNamed:@"conversation-icon-me"];
        } else {
            cell.latestMessageDirection.image = nil;
        }
    }
    [cell.latestMessageLabel sizeToFit];
    
    

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
        cell.latestMessageTimeLabel.text = [formatter stringFromDate: latestMessageTime];
    } else {
        cell.latestMessageTimeLabel.text = @"";
    }
    cell.hasNewMessages = contact.unreadMessages.count > 0;

    [self layoutFirstRowLabels: cell];
}

- (void) layoutFirstRowLabels: (ConversationCell*) cell {
    ConversationCell * prototype = self.conversationCell;
    CGFloat dateLabelRightEdge;
    if (cell.latestMessageDirection.image == nil) {
        dateLabelRightEdge = prototype.latestMessageDirection.frame.origin.x + prototype.latestMessageDirection.frame.size.width;
    } else {
        dateLabelRightEdge = prototype.latestMessageTimeLabel.frame.origin.x + prototype.latestMessageTimeLabel.frame.size.width;
    }
    [cell.latestMessageTimeLabel sizeToFit];
    CGRect frame = prototype.latestMessageTimeLabel.frame;
    frame.origin.x = dateLabelRightEdge - cell.latestMessageTimeLabel.frame.size.width;
    frame.size.width = cell.latestMessageTimeLabel.frame.size.width;
    cell.latestMessageTimeLabel.frame = frame;

    CGFloat nickToDatePadding = prototype.latestMessageTimeLabel.frame.origin.x - CGRectGetMaxX(prototype.nickName.frame);
    frame = prototype.nickName.frame;
    frame.size.width = cell.latestMessageTimeLabel.frame.origin.x - nickToDatePadding - prototype.nickName.frame.origin.x;
    cell.nickName.frame = frame;
}

@end
