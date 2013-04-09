//
//  ContactListViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"

#import "ContactListViewCells.h"
#import "InsetImageView.h"
#import "Contact.h"
#import "AppDelegate.h"
#import "ConversationViewController.h"
#import "ChatViewController.h"
#import "MFSideMenu.h"
#import "iOSVersionChecks.h"
#import "HoccerTalkBackend.h"
#import "InviteCodeViewController.h"


@interface ContactListViewController ()
@property (nonatomic, strong) NSFetchedResultsController *searchFetchedResultsController;
@property (nonatomic, strong) NSMutableArray * invitationChannels;
@end

static const NSTimeInterval kInvitationTokenValidity = 60 * 60 * 24 * 7; // one week

@interface InvitationChannel : NSObject
@property (nonatomic,strong) NSString* localizedButtonTitle;
@property (nonatomic, assign) SEL handler;
@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize chatBackend = _chatBackend;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.searchBar.backgroundImage = [[UIImage imageNamed: @"contact_cell_bg"]  resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    UIImage *searchFieldImage = [[UIImage imageNamed:@"searchbar_input-text"]
                                 resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 15, 14)];
    [self.searchBar setSearchFieldBackgroundImage:searchFieldImage forState:UIControlStateNormal];
    for (UIView *subview in self.searchBar.subviews){
        if([subview isKindOfClass: UITextField.class]){
            [(UITextField*)subview setTextColor: [UIColor whiteColor]];
        }
    }
    self.searchBar.delegate = self;
    self.searchBar.placeholder = NSLocalizedString(@"search", @"Contact List Search Placeholder");

    self.tableView.contentOffset = CGPointMake(0, 44);
    
    UIImage *inviteButtonBackground = [[UIImage imageNamed:@"chatbar_btn-send"] stretchableImageWithLeftCapWidth:25 topCapHeight:0];
    [self.inviteButton setBackgroundImage: inviteButtonBackground forState: UIControlStateNormal];
    [self.inviteButton setBackgroundColor: [UIColor clearColor]];

    self.invitationChannels = [[NSMutableArray alloc] initWithCapacity: 2];
    if ([MFMessageComposeViewController canSendText]) {
        InvitationChannel * channel = [[InvitationChannel alloc] init];
        channel.localizedButtonTitle = NSLocalizedString(@"SMS",@"Invite Actionsheet Button Title");
        channel.handler = @selector(inviteBySMS);
        [self.invitationChannels addObject: channel];
    }
    if ([MFMailComposeViewController canSendMail]) {
        InvitationChannel * channel = [[InvitationChannel alloc] init];
        channel.localizedButtonTitle = NSLocalizedString(@"Mail",@"Invite Actionsheet Button Title");
        channel.handler = @selector(inviteByMail);
        [self.invitationChannels addObject: channel];
    }
    InvitationChannel * channel = [[InvitationChannel alloc] init];
    channel.localizedButtonTitle = NSLocalizedString(@"Invite Code", @"Invite Actionsheet Button Title");
    channel.handler = @selector(inviteByCode);
    [self.invitationChannels addObject: channel];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSFetchedResultsController *)currentFetchedResultsController {
    return self.searchBar.text.length ? self.searchFetchedResultsController : self.fetchedResultsController;
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self currentFetchedResultsController].sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self currentFetchedResultsController].sections[section];
    return sectionInfo.numberOfObjects;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactCell *cell = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0") ?
    [tableView dequeueReusableCellWithIdentifier: [ContactCell reuseIdentifier] forIndexPath:indexPath] :
    [tableView dequeueReusableCellWithIdentifier: [ContactCell reuseIdentifier]];
    
    if (cell.backgroundView == nil) {
        // TODO: do this right ...
        cell.backgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.backgroundView.frame = cell.frame;
        cell.avatar.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.2];
        cell.avatar.borderColor = [UIColor blackColor];
    }
    [self fetchedResultsController: [self currentFetchedResultsController]
                     configureCell: cell atIndexPath: indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo name];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];

        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.searchBar resignFirstResponder];
    Contact * contact = (Contact*)[[self fetchedResultsController] objectAtIndexPath:indexPath];
    [_conversationViewController.chatViewController setPartner: contact];
    NSArray * viewControllers = @[_conversationViewController, _conversationViewController.chatViewController];
    [self.sideMenu.navigationController setViewControllers: viewControllers animated: NO];
    [self.sideMenu setMenuState:MFSideMenuStateClosed];
}

#pragma mark - Search Bar

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchFetchedResultsController.delegate = nil;
    self.searchFetchedResultsController = nil;
    [self.tableView reloadData];
}

#pragma mark - Fetched results controller

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    return _managedObjectContext;
}

- (NSFetchedResultsController *)newFetchedResultsControllerWithSearch:(NSString *)searchString {
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES];
    NSArray *sortDescriptors = @[sortDescriptor];

    //NSArray *sortDescriptors = // your sort descriptors here
    NSPredicate *filterPredicate = nil; // your predicate here

    /*
     Set up the fetched results controller.
     */
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *callEntity = [NSEntityDescription entityForName: [Contact entityName] inManagedObjectContext: self.managedObjectContext];
    [fetchRequest setEntity:callEntity];

    NSMutableArray *predicateArray = [NSMutableArray array];
    if(searchString.length) {
        // your search predicate(s) are added to this array
        [predicateArray addObject:[NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@", searchString]];
        // finally add the filter predicate for this view
        if(filterPredicate)
        {
            filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:filterPredicate, [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray], nil]];
        }
        else
        {
            filterPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
        }
    }
    [fetchRequest setPredicate:filterPredicate];

    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];

    [fetchRequest setSortDescriptors:sortDescriptors];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                                managedObjectContext:self.managedObjectContext
                                                                                                  sectionNameKeyPath: @"relationship.state"
                                                                                                           cacheName:nil];
    aFetchedResultsController.delegate = self;

    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.

         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return aFetchedResultsController;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil)
    {
        return _fetchedResultsController;
    }
    _fetchedResultsController = [self newFetchedResultsControllerWithSearch:nil];
    return _fetchedResultsController;
}

- (NSFetchedResultsController *)searchFetchedResultsController {
    if (_searchFetchedResultsController != nil)
    {
        return _searchFetchedResultsController;
    }
    _searchFetchedResultsController = [self newFetchedResultsControllerWithSearch:self.searchBar.text];
    return _searchFetchedResultsController;
}



- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
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

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self fetchedResultsController: controller configureCell: (ContactCell*)[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;

        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
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


- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)cell
                     atIndexPath:(NSIndexPath *)indexPath
{
    // your cell guts here
    Contact * contact = (Contact*)[fetchedResultsController objectAtIndexPath:indexPath];
    cell.nickName.text = contact.nickName;
    cell.avatar.image = contact.avatarImage;
    BOOL hasUnreadMessages = contact.unreadMessages.count > 0;
    [cell setMessageCount: hasUnreadMessages ? contact.unreadMessages.count : contact.messages.count isUnread: hasUnreadMessages];
}

#pragma mark - Invitations

- (IBAction) invitePressed:(id)sender {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"Invite by", @"Actionsheet Title")
                                                        delegate: self
                                               cancelButtonTitle: nil
                                          destructiveButtonTitle: nil
                                               otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    for (InvitationChannel * channel in self.invitationChannels) {
        [sheet addButtonWithTitle: channel.localizedButtonTitle];
    }
    sheet.cancelButtonIndex = [sheet addButtonWithTitle: NSLocalizedString(@"Cancel", @"Actionsheet Button Title")];

    [sheet showInView: self.view];

}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector: ((InvitationChannel*)self.invitationChannels[buttonIndex]).handler];
#pragma clang diagnostic pop
}

- (void) inviteByMail {
    [self.chatBackend generateToken: @"pairing" validFor: kInvitationTokenValidity tokenHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
        picker.mailComposeDelegate = self;

        [picker setSubject: NSLocalizedString(@"invitation_mail_subject", @"Mail Invitation Subject")];

        NSString * body = NSLocalizedString(@"invitation_mail_body", @"Mail Invitation Body");
        NSString * inviteLink = [self inviteURL: token];
        NSString * appStoreLink = [self appStoreURL];
        NSString * androidLink = [self androidURL];
        body = [NSString stringWithFormat: body, appStoreLink, androidLink, inviteLink];
        [picker setMessageBody:body isHTML:NO];

        [self.sideMenu setMenuState:MFSideMenuStateClosed];
        [self.sideMenu.navigationController.topViewController presentModalViewController: picker animated: YES];
    }];
}

- (void) inviteBySMS {
    [self.chatBackend generateToken: @"pairing" validFor: kInvitationTokenValidity tokenHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
        picker.messageComposeDelegate = self;

        NSString * smsText = NSLocalizedString(@"invitation_sms_text", @"SMS Invitation Body");
        picker.body = [NSString stringWithFormat: smsText, [self inviteURL: token]];
        
        [self.sideMenu setMenuState:MFSideMenuStateClosed];
        [self.sideMenu.navigationController.topViewController presentModalViewController: picker animated: YES];

    }];
}

- (void) inviteByCode {
    UIStoryboard * storyboard;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:[NSBundle mainBundle]];
    } else {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:[NSBundle mainBundle]];
    }

    InviteCodeViewController * controller = [storyboard instantiateViewControllerWithIdentifier:@"inviteCodeView"];

    [self.sideMenu setMenuState:MFSideMenuStateClosed];
    [self.sideMenu.navigationController.topViewController presentModalViewController: controller animated: YES];

}

- (NSString*) inviteURL: (NSString*) token {
    return [NSString stringWithFormat: @"hctalk://%@", token];
}

- (NSString*) appStoreURL {
    return @"itms-apps://itunes.com/apps/hoccertalk";
}

- (NSString*) androidURL {
    return @"http://google.com";
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {

    // TODO: handle mail result?
	switch (result) {
		case MFMailComposeResultCancelled:
			break;
		case MFMailComposeResultSaved:
			break;
		case MFMailComposeResultSent:
			break;
		case MFMailComposeResultFailed:
			break;
		default:
			break;
	}
    [self.sideMenu.navigationController.topViewController dismissModalViewControllerAnimated: NO];
    [self reopenMenu];
    //[NSTimer scheduledTimerWithTimeInterval: 0.6 target: self selector: @selector(reopenMenu) userInfo:nil repeats:NO];
}

- (void) reopenMenu {
    [self.sideMenu setMenuState: MFSideMenuStateRightMenuOpen];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result {

    // TODO: handle message result?
	switch (result) {
		case MessageComposeResultCancelled:
			break;
		case MessageComposeResultSent:
			break;
		case MessageComposeResultFailed:
			break;
		default:
			break;
	}
    [self.sideMenu.navigationController.topViewController dismissModalViewControllerAnimated: NO];
    [self reopenMenu];
    //[NSTimer scheduledTimerWithTimeInterval: 0.6 target: self selector: @selector(reopenMenu) userInfo:nil repeats:NO];
}

- (HoccerTalkBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

- (void)viewDidUnload {
    [self setInviteButton:nil];
    [super viewDidUnload];
}

@end

@implementation InvitationChannel
@end