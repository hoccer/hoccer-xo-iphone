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
#import "GridView.h"


//#define HIDE_SEPARATORS

@interface ConversationViewController ()

@property (nonatomic,readonly) ConversationCell * conversationCell;

@property (strong, nonatomic) id connectionInfoObserver;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

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
	// Do any additional setup after loading the view, typically from a nib.

    UIBarButtonItem *addContactButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed: @"navbar-icon-add"] landscapeImagePhone: nil style: UIBarButtonItemStylePlain target: self action: @selector(inviteFriendsPressed:)];

    self.navigationItem.rightBarButtonItem = addContactButton;

    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"back_button_title", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

    self.navigationItem.title = NSLocalizedString(@"Chats", nil);

    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];
    
    
    GridView * grid = nil;//[[GridView alloc] initWithFrame: self.view.bounds];
    [self.view addSubview: grid];
    [self.view bringSubviewToFront: grid];
    
    self.tableView.rowHeight = [self.conversationCell.contentView systemLayoutSizeFittingSize: UILayoutFittingCompressedSize].height;
    self.tableView.separatorInset = self.conversationCell.separatorInset;
#ifdef HIDE_SEPARATORS
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
#endif
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    [self.conversationCell preferredContentSizeChanged: notification];
    self.tableView.rowHeight = [self.conversationCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    [self.tableView reloadData];
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
        UINavigationController * profileView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalProfileViewController"];
        [self.navigationController presentViewController: profileView animated: YES completion: nil];
    }
    // [AppDelegate setDefaultAudioSession]; // should be removed when a better AudioPlayer is in Place; right now we set the default mode here in case an Audio has been played and the MusicSession has been enabled
    self.view.userInteractionEnabled = YES;
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
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        return 0;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [self dequeueReusableCellOfClass: [ConversationCell class] forIndexPath: indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL) isLastCell: (NSIndexPath*) indexPath {
    return indexPath.section == [self numberOfSectionsInTableView: self.tableView] - 1 && indexPath.row == [self tableView: self.tableView numberOfRowsInSection: indexPath.section] - 1;
}

- (void) inviteFriendsPressed: (id) sender {
    [[InvitationController sharedInvitationController] presentWithViewController: self];
}
/*
- (CGFloat) tableView: (UITableView*) tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self.conversationCell sizeThatFits: CGSizeMake(self.tableView.bounds.size.width, 0)].height;
    return self.conversationCell.bounds.size.height;
}
 */

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
    
    [self performSegueWithIdentifier: @"showChat" sender: self];
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

@synthesize managedObjectContext = _managedObjectContext;

- (NSManagedObjectContext*) managedObjectContext {
    if (_managedObjectContext == nil) {
        _managedObjectContext = ((AppDelegate*)[UIApplication sharedApplication].delegate).managedObjectContext;
    }
    return _managedObjectContext;
}

@synthesize fetchedResultsController = _fetchedResultsController;
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
    NSSortDescriptor *sortDescriptor2 = [[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES];
    NSArray *sortDescriptors = @[sortDescriptor, sortDescriptor2];

    [fetchRequest setSortDescriptors:sortDescriptors];

    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat: @"relationshipState == 'friend' OR relationshipState == 'kept' OR relationshipState == 'blocked' OR (type == 'Group' AND (myGroupMembership.state == 'joined' OR myGroupMembership.group.groupState == 'kept'))"];
    [fetchRequest setPredicate: filterPredicate];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    //NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Contacts"];
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil]; // fetchrequest will not reflect changes in the filter during development when cached
    aFetchedResultsController.delegate = self;
    _fetchedResultsController = aFetchedResultsController;
    
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
    //NSLog(@"Conv controllerWillChangeContent");
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    //NSLog(@"Conv didChangeSection");
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        return;
    }
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
    //NSLog(@"Conv didChangeObject newIndexPath=%@, indexPath=%@",newIndexPath, indexPath);
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        return;
    }
    UITableView *tableView = self.tableView;
    switch(type) {
        case NSFetchedResultsChangeInsert:
            //NSLog(@"Conv NSFetchedResultsChangeInsert");
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            //NSLog(@"Conv NSFetchedResultsChangeInsert");
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            //NSLog(@"Conv NSFetchedResultsChangeUpdate");
            /* workaround - see:
             * http://stackoverflow.com/questions/14354315/simultaneous-move-and-update-of-uitableviewcell-and-nsfetchedresultscontroller
             * and
             * http://developer.apple.com/library/ios/#releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/
             */
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:newIndexPath ? newIndexPath : indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            //NSLog(@"Conv NSFetchedResultsChangeMove");
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"Conv controllerDidChangeContent");
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
    //NSLog(@"Conv configureCell atIndexPath=%@",indexPath);
    ConversationCell * cell = (ConversationCell*)aCell;
    Contact * contact = (Contact*)[self.fetchedResultsController objectAtIndexPath:indexPath];

    // cell.nickName.text = contact.nickName;
    cell.nickName.text = contact.nickNameWithStatus;
    cell.nickName.ledOn = [contact.connectionStatus isEqualToString: @"online"];

    UIImage * avatar = contact.avatarImage;
    if (avatar == nil) {
        NSString * avatarName = [contact.type isEqualToString: @"Group"] ?  @"avatar_default_group" : @"avatar_default_contact";
        avatar = [UIImage imageNamed: avatarName];
    }
    [cell.avatar setImage: avatar forState: UIControlStateNormal];
    cell.avatar.showLed = NO;
    
    //cell.latestMessageLabel.frame = self.conversationCell.latestMessageLabel.frame;
    NSDate * latestMessageTime = nil;
    if ([contact.latestMessage count] == 0){
        cell.subtitleLabel.text = nil;
    } else {
        HXOMessage * message = contact.latestMessage[0];
        if (message.body.length > 0) {
            cell.subtitleLabel.text = message.body;
            cell.subtitleLabel.font = [UIFont systemFontOfSize: cell.subtitleLabel.font.pointSize];
        } else {
            if (message.attachment != nil) {
                cell.subtitleLabel.text = [NSString stringWithFormat:@"[%@]", NSLocalizedString(message.attachment.mediaType,nil)];
            } else {
                cell.subtitleLabel.text = @"<>"; // should never happen
            }
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
