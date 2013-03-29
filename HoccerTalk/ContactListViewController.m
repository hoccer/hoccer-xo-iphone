//
//  ContactListViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"
#import "ContactCell.h"
#import "BezeledImageView.h"
#import "Contact.h"
#import "AppDelegate.h"
#import "ConversationViewController.h"
#import "ChatViewController.h"
#import "MFSideMenu.h"

@interface ContactListViewController ()
@property (nonatomic, retain) NSFetchedResultsController *searchFetchedResultsController;
@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.searchBar.backgroundImage = [[UIImage imageNamed: @"searchbar_bg"]  resizableImageWithCapInsets:UIEdgeInsetsMake(1, 1, 1, 1)];
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
    ContactCell *cell = [tableView dequeueReusableCellWithIdentifier: [ContactCell reuseIdentifier] forIndexPath:indexPath];
    if (cell.backgroundView == nil) {
        // TODO: do this right ...
        cell.backgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.backgroundView.frame = cell.frame;
        cell.avatar.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.2];
        cell.avatar.bezelColor = [UIColor blackColor];
    }
    [self fetchedResultsController: [self currentFetchedResultsController]
                     configureCell: cell atIndexPath: indexPath];
    return cell;
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
    NSEntityDescription *callEntity = [NSEntityDescription entityForName: @"Contact" inManagedObjectContext: self.managedObjectContext];
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
                                                                                                  sectionNameKeyPath:nil
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

@end
