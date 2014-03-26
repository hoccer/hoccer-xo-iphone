//
//  ContactListViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"

#import "Contact.h"
#import "Group.h"
#import "ContactCell.h"
#import "AppDelegate.h"
#import "InviteCodeViewController.h"
#import "HXOBackend.h"
#import "ProfileViewController.h"
#import "InvitationController.h"
#import "HXOTheme.h"
#import "Group.h"
#import "GroupMembership.h"

#define HIDE_SEPARATORS

extern const CGFloat kHXOGridSpacing;
static const CGFloat kMagicSearchBarHeight = 44;

@interface ContactListViewController ()

@property (nonatomic,strong) UISegmentedControl *                    groupContactsToggle;

@property (nonatomic, strong) NSFetchedResultsController *           searchFetchedResultsController;
@property (strong, nonatomic, readonly) NSFetchedResultsController * fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *               managedObjectContext;

@property (nonatomic, readonly) ContactCell *                        contactCellPrototype;
@property id keyboardHidingObserver;
@property (strong, nonatomic) id connectionInfoObserver;

@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;

- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [ContactCell class]];
    
    if (self.hasAddButton) {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd target: self action: @selector(addButtonPressed:)];
        self.navigationItem.rightBarButtonItem = addButton;
    }
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"back_button_title", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

    [self setupTitle];

    if ( ! self.searchBar) {
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, kMagicSearchBarHeight)];
        self.tableView.tableHeaderView = self.searchBar;
    }
    self.searchBar.delegate = self;
    self.searchBar.placeholder = NSLocalizedString(@"search", @"Contact List Search Placeholder");
    self.tableView.contentOffset = CGPointMake(0, self.searchBar.bounds.size.height);

    [HXOBackend registerConnectionInfoObserverFor:self];
    self.keyboardHidingObserver = [AppDelegate registerKeyboardHidingOnSheetPresentationFor:self];

    self.tableView.rowHeight = [self calculateRowHeight];
    // Apple bug: Order matters. Setting the inset before the color leaves the "no cell separators" in the wrong color.
    self.tableView.separatorColor = [[HXOTheme theme] tableSeparatorColor];
    self.tableView.separatorInset = self.contactCellPrototype.separatorInset;
#ifdef HIDE_SEPARATORS
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
#endif

    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void) setupTitle {
    if (self.hasGroupContactToggle) {
        self.groupContactsToggle = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"Contacts", nil), NSLocalizedString(@"group_segment_title", nil)]];
        self.groupContactsToggle.selectedSegmentIndex = 0;
        [self.groupContactsToggle addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
        self.navigationItem.titleView = self.groupContactsToggle;
    }
}

- (CGFloat) calculateRowHeight {
    return ceilf([self.contactCellPrototype.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height / kHXOGridSpacing) * kHXOGridSpacing;
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    [self.contactCellPrototype preferredContentSizeChanged: notification];
    self.tableView.rowHeight = [self calculateRowHeight];
    [self.tableView reloadData];
}

- (void) segmentChanged: (id) sender {
    self.currentFetchedResultsController.delegate = nil;
    [self clearFetchedResultsControllers];
    [self.tableView reloadData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self.keyboardHidingObserver];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [HXOBackend broadcastConnectionInfo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.view endEditing:NO]; // hide keyboard on scrolling
}

- (void) addButtonPressed: (id) sender {
    if (self.groupContactsToggle) {
        if (self.groupContactsToggle.selectedSegmentIndex == 0) {
            [[InvitationController sharedInvitationController] presentWithViewController: self];
        } else {
            UINavigationController * modalGroupView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalGroupNavigationController"];
            [self presentViewController: modalGroupView animated: YES completion:nil];
        }
    } else {
        [[InvitationController sharedInvitationController] presentWithViewController: self];
    }
}

- (ContactCell*) contactCellPrototype {
     return (ContactCell*)[self prototypeCellOfClass: [ContactCell class]];
}

- (NSFetchedResultsController *)currentFetchedResultsController {
    return self.searchBar.text.length ? self.searchFetchedResultsController : self.fetchedResultsController;
}

- (void) clearFetchedResultsControllers {
    _fetchedResultsController.delegate = nil;
    _fetchedResultsController = nil;
    _searchFetchedResultsController.delegate = nil;
    _searchFetchedResultsController = nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.currentFetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
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

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier: @"showContact" sender: self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showContact"]) {
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
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: [self entityName] inManagedObjectContext: self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors: self.sortDescriptors];

    NSMutableArray *predicateArray = [NSMutableArray array];
    [self addPredicates: predicateArray];
    if(searchString.length) {
        [self addSearchPredicates: predicateArray searchString: searchString];
    }
    NSPredicate * filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicateArray];
    [fetchRequest setPredicate:filterPredicate];

    [fetchRequest setFetchBatchSize:20];

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

- (NSArray*) sortDescriptors {
    return @[[[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES]];
}

- (void) addPredicates: (NSMutableArray*) predicates {
    if ([self.entityName isEqualToString: @"Contact"]) {
        [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@ AND (relationshipState == 'friend' OR relationshipState == 'blocked' OR relationshipState == 'kept' OR relationshipState == 'groupfriend')", [self entityName]]];
    } /* else {
       [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@", [self entityName]]];
    } */
}

- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString {
    [predicates addObject: [NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@", searchString]];
}

- (id) entityName {
    if (self.hasGroupContactToggle) {
        if (self.groupContactsToggle.selectedSegmentIndex == 0) {
            return [Contact entityName];
        } else {
            return [Group entityName];
        }
    }
    return [Contact entityName];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    _fetchedResultsController = [self newFetchedResultsControllerWithSearch: nil];
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

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            /* workaround - see:
             * http://stackoverflow.com/questions/14354315/simultaneous-move-and-update-of-uitableviewcell-and-nsfetchedresultscontroller
             * and
             * http://developer.apple.com/library/ios/#releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/
             */
            [self fetchedResultsController: controller configureCell: (ContactCell*)[self.tableView cellForRowAtIndexPath:indexPath]
                               atIndexPath: newIndexPath ? newIndexPath : indexPath];
            break;

        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}


- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)cell
                     atIndexPath:(NSIndexPath *)indexPath
{
    Contact * contact = (Contact*)[fetchedResultsController objectAtIndexPath:indexPath];
    cell.nickName.text = contact.nickNameWithStatus;
    cell.nickName.ledOn = [contact.connectionStatus isEqualToString: @"online"];

    
    UIImage * avatar = contact.avatarImage;
    if (avatar == nil) {
        NSString * avatarName = [contact.type isEqualToString: @"Group"] ?  @"avatar_default_group" : @"avatar_default_contact";
        avatar = [UIImage imageNamed: avatarName];
    }
    [cell.avatar setImage: avatar forState: UIControlStateNormal];
    
    cell.subtitleLabel.text = [self statusStringForContact: contact];
}

- (NSString*) statusStringForContact: (Contact*) contact {
    if ([contact isKindOfClass: [Group class]]) {
        Group * group = (Group*)contact;
        NSInteger joinedMemberCount = [group.otherJoinedMembers count];
        NSInteger invitedMemberCount = [group.otherInvitedMembers count];

        NSString * joinedStatus = @"";

        if ([group.groupState isEqualToString:@"kept"]) {
            joinedStatus = NSLocalizedString(@"Group Deactivated", nil);
        } else if ([group.myGroupMembership.state isEqualToString:@"invited"]){
            joinedStatus = NSLocalizedString(@"Invitation not yet accepted", nil);
        } else {
            if (group.iAmAdmin) {
                joinedStatus = NSLocalizedString(@"Admin", nil);
            }
            if (joinedMemberCount > 0) {
                if (joinedStatus.length>0) {
                    joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
                }
                if (joinedMemberCount > 1) {
                    joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@%d joined",nil), joinedStatus,joinedMemberCount];
                } else {
                    joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@one joined",nil), joinedStatus];
                }
            } else {
                if (joinedStatus.length>0) {
                    joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
                }
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@you are alone",nil), joinedStatus,joinedMemberCount];

            }
            if (invitedMemberCount > 0) {
                if (joinedStatus.length>0) {
                    joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
                }
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"%@%d invited",nil), joinedStatus,invitedMemberCount];
            }
        }
        return joinedStatus;
    } else {
        return NSLocalizedString(contact.relationshipState, nil);
    }
}

@end
