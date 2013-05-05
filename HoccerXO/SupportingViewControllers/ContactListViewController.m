//
//  ContactListViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"

#import "UIViewController+HXOSideMenuButtons.h"
#import "InsetImageView.h"
#import "Contact.h"
#import "ContactCell.h"
#import "AppDelegate.h"
#import "RadialGradientView.h"
#import "InviteCodeViewController.h"
#import "HXOBackend.h"
#import "ProfileViewController.h"
#import "InvitationController.h"


@interface ContactListViewController ()

@property (nonatomic, strong) NSFetchedResultsController *searchFetchedResultsController;
@property (nonatomic, readonly) NSFetchedResultsController * currentFetchedResultsController;
@property (strong, nonatomic, readonly) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, readonly) ContactCell * contactCellPrototype;

@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize contactCellPrototype = _contactCellPrototype;

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = self.hxoMenuButton;

    UIBarButtonItem *addContactButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed: @"navbar-icon-add"] landscapeImagePhone: nil style: UIBarButtonItemStylePlain target: self action: @selector(addContactPressed:)];
    self.navigationItem.rightBarButtonItem = addContactButton;

    UIImage * blueBackground = [[UIImage imageNamed: @"navbar-btn-blue"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
    [self.navigationItem.rightBarButtonItem setBackgroundImage: blueBackground forState: UIControlStateNormal barMetrics: UIBarMetricsDefault];

    self.tableView.backgroundView = [[RadialGradientView alloc] initWithFrame: self.tableView.frame];

    self.searchBar.delegate = self;
    self.searchBar.placeholder = NSLocalizedString(@"search", @"Contact List Search Placeholder");
    self.tableView.contentOffset = CGPointMake(0, self.searchBar.bounds.size.height);

    UIImage * icon = [UIImage imageNamed: @"navbar-icon-contacts"];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage: icon style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

    [HXOBackend registerConnectionInfoObserverFor:self];

}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
    [HXOBackend broadcastConnectionInfo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) addContactPressed: (id) sender {
    [[InvitationController sharedInvitationController] presentWithViewController: self];
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

    cell.avatar.image = contact.avatarImage != nil ? contact.avatarImage : [UIImage imageNamed: @"avatar_default_contact"];
}

@end
