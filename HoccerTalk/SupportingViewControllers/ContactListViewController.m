//
//  ContactListViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"

#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "InsetImageView.h"
#import "Contact.h"
#import "ContactCell.h"
#import "AppDelegate.h"
#import "RadialGradientView.h"
#import "InviteCodeViewController.h"
#import "HoccerTalkBackend.h"
#import "ProfileViewController.h"

static const NSTimeInterval kInvitationTokenValidity = 60 * 60 * 24 * 7; // one week

@interface InvitationChannel : NSObject
@property (nonatomic,strong) NSString* localizedButtonTitle;
@property (nonatomic, assign) SEL handler;
@end


@interface ContactListViewController ()

@property (nonatomic, strong) NSFetchedResultsController *searchFetchedResultsController;
@property (nonatomic, strong) NSMutableArray * invitationChannels;
@property (nonatomic, readonly) NSFetchedResultsController * currentFetchedResultsController;
@property (strong, nonatomic, readonly) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) HoccerTalkBackend * chatBackend;

@property (nonatomic, readonly) ContactCell * contactCellPrototype;

@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize contactCellPrototype = _contactCellPrototype;
@synthesize chatBackend = _chatBackend;

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = self.hoccerTalkMenuButton;

    UIBarButtonItem *addContactButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed: @"navbar-icon-add"] landscapeImagePhone: nil style: UIBarButtonItemStylePlain target: self action: @selector(addContactPressed:)];
    self.navigationItem.rightBarButtonItem = addContactButton;

    UIImage * blueBackground = [[UIImage imageNamed: @"navbar-btn-blue"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
    [self.navigationItem.rightBarButtonItem setBackgroundImage: blueBackground forState: UIControlStateNormal barMetrics: UIBarMetricsDefault];

    self.tableView.backgroundView = [[RadialGradientView alloc] initWithFrame: self.tableView.frame];

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

    self.searchBar.delegate = self;
    self.searchBar.placeholder = NSLocalizedString(@"search", @"Contact List Search Placeholder");
    self.tableView.contentOffset = CGPointMake(0, self.searchBar.bounds.size.height);

    UIImage * icon = [UIImage imageNamed: @"navbar-icon-contacts"];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage: icon style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) addContactPressed: (id) sender {
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

- (ContactCell*) contactCellPrototype {
    if (_contactCellPrototype == nil) {
        _contactCellPrototype = [self.tableView dequeueReusableCellWithIdentifier: [ContactCell reuseIdentifier]];
    }
    return _contactCellPrototype;
}

- (NSFetchedResultsController *)currentFetchedResultsController {
    return self.searchBar.text.length ? self.searchFetchedResultsController : self.fetchedResultsController;
}

#pragma mark - Table view data source

- (BOOL) isEmpty {
    if (self.currentFetchedResultsController.sections.count == 0) {
        return YES;
    } else {
        id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[0];
        return [sectionInfo numberOfObjects] == 0;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.emptyTablePlaceholder != nil) {
        return 1;
    }
    return [self.currentFetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.emptyTablePlaceholder != nil) {
        return 1;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (CGFloat) tableView: (UITableView*) tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.emptyTablePlaceholder != nil ? self.emptyTablePlaceholder.bounds.size.height : self.contactCellPrototype.bounds.size.height;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.emptyTablePlaceholder) {
        self.emptyTablePlaceholder.placeholder.text = NSLocalizedString(@"contacts_empty_placeholder", nil);
        self.emptyTablePlaceholder.icon.image = [UIImage imageNamed: @"xo.png"];
        return self.emptyTablePlaceholder;
    }
    ContactCell *cell = [tableView dequeueReusableCellWithIdentifier: [ContactCell reuseIdentifier] forIndexPath:indexPath];

    // TODO: do this right ...
    [self fetchedResultsController: self.currentFetchedResultsController
                     configureCell: cell atIndexPath: indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[section];
    return [sectionInfo name];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showProfile"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
        ProfileViewController* profileView = (ProfileViewController*)[segue destinationViewController];
        profileView.contact = contact;
    }
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
    NSSortDescriptor *nameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES];
    NSArray *sortDescriptors = @[nameSortDescriptor];

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
        } else {
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
                                                                                                  sectionNameKeyPath: nil
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
    _searchFetchedResultsController = [self newFetchedResultsControllerWithSearch: self.searchBar.text];
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

    [self updateEmptyTablePlaceholderAnimated: YES];
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
    // cell.nickName.text = contact.nickName;
    cell.nickName.text = contact.nickNameWithStatus;

    cell.avatar.image = contact.avatarImage;
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

        [self.navigationController presentModalViewController: picker animated: YES];
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

        [self.navigationController presentModalViewController: picker animated: YES];

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

    [self.navigationController presentModalViewController: controller animated: YES];

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
    [self dismissModalViewControllerAnimated: NO];
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
    [self dismissModalViewControllerAnimated: NO];
}


- (HoccerTalkBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}


@end

@implementation InvitationChannel
@end
