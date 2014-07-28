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
#import "HXOBackend.h"
#import "DatasheetViewController.h"
#import "HXOUI.h"
#import "Group.h"
#import "GroupMembership.h"
#import "HXOUI.h"
#import "LabelWithLED.h"
#import "avatar_contact.h"
#import "avatar_group.h"
#import "avatar_location.h"
#import "AvatarView.h"
#import "HXOUserDefaults.h"
#import "InvitationCodeViewController.h"
#import "ContactCellProtocol.h"
#import "GroupInStatuNascendi.h"
#import "WebViewController.h"
#import "tab_contacts.h"
#import "HXOPluralocalization.h"

#define HIDE_SEPARATORS
#define FETCHED_RESULTS_DEBUG NO
#define FETCHED_RESULTS_DEBUG_PERF NO
#define VIEW_UPDATING_DEBUG NO

//#define SEARCHBAR_SCROLLING_IN_HACK
#define SEARCHBAR_SCROLLING_DEBUG NO
#define SEARCHBAR_SCROLLING_IN_HACK_ACTIVE NO

#define SEPERATOR_DEBUG NO


//#define SEARCHBAR_SCROLLING_IN_HACK_B

#define LATEST_SCROLL_BUGFIX


static const CGFloat kMagicSearchBarHeight = 44;

@interface ContactListViewController ()

@property (nonatomic, strong)   NSFetchedResultsController  * searchFetchedResultsController;
@property (nonatomic, readonly) NSFetchedResultsController  * fetchedResultsController;
//@property (nonatomic, strong)   NSManagedObjectContext      * managedObjectContext;

@property                       id                            keyboardHidingObserver;
@property (strong, nonatomic)   id                            connectionInfoObserver;
@property (nonatomic, readonly) HXOBackend                  * chatBackend;

@property (nonatomic, readonly) UITableViewCell             * cellPrototype;
@property (nonatomic, readonly) UIView                      * placeholderView;
@property (nonatomic, readonly) UIImageView                 * placeholderImageView;
@property (nonatomic, readonly) HXOHyperLabel               * placeholderLabel;
@property (nonatomic, readonly) BOOL                          inGroupMode;

@property (nonatomic, readonly) UINavigationController      * webViewController;

@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize placeholderView = _placeholderView;
@synthesize placeholderImageView = _placeholderImageView;
@synthesize placeholderLabel = _placeholderLabel;
@synthesize webViewController = _webViewController;


#ifdef SEARCHBAR_SCROLLING_IN_HACK
CGPoint _correctContentOffset;
#endif

- (void)awakeFromNib {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];

    self.tabBarItem.image = [[[tab_contacts alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"contact_list_nav_title", nil);
}

#ifdef SEARCHBAR_SCROLLING_IN_HACK

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqual:@"contentOffset"]) {
        // This is hack #2 to correct some misbehavior of the Apples' UIKit
        // It actually changes the content offset without firing a notification;
        // Here we detect if the value has changes without notification and
        // restore it to the correct old value; we have to do it asynchronously
        // because otherwise UIKit will change it again
        
        if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"contentOffset changed, dict = %@", change);
        if (SEARCHBAR_SCROLLING_IN_HACK_ACTIVE) {
            CGPoint newOffset;
            [change[NSKeyValueChangeNewKey] getValue:&newOffset];
            CGPoint oldOffset;
            [change[NSKeyValueChangeOldKey] getValue:&oldOffset];
            
            if (oldOffset.x != _correctContentOffset.x || oldOffset.y != _correctContentOffset.y) {
                if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"correcting offset to = %@", NSStringFromCGPoint(_correctContentOffset));
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView setContentOffset:_correctContentOffset];
                });
            } else {
                _correctContentOffset = newOffset;
            }
        }
    }
    if ([keyPath isEqual:@"contentSize"]) {
        if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"contentSize changed, dict = %@", change);
        CGSize newSize;
        [change[NSKeyValueChangeNewKey] getValue:&newSize];
        CGSize oldSize;
        [change[NSKeyValueChangeOldKey] getValue:&oldSize];
        
        UIEdgeInsets currentInset = self.tableView.contentInset;
        CGFloat minSize = self.tableView.bounds.size.height - currentInset.top - currentInset.bottom;
        NSLog(@"newSize = %f, minSize = %f", newSize.height, minSize);
        if (newSize.height < minSize) {
            NSLog(@"Readjusting content size to minsize=%f", minSize);
            self.tableView.contentSize = CGSizeMake(newSize.width, minSize);
        }
    }
    if ([keyPath isEqual:@"contentInset"]) {
        // this is hack #1 to correct some misbehavior of the Apples' UIKit
        // When the contentInset changes, the scroll position is actually correct,
        // but it is subsequently changed to wrong scoll position
        // In this hack we just set the correct position after 1 sec
        if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"contentInset changed, dict = %@", change);
        
        if (SEARCHBAR_SCROLLING_IN_HACK_ACTIVE) {
            UIEdgeInsets newInset;
            [change[NSKeyValueChangeNewKey] getValue:&newInset];
            UIEdgeInsets oldInset;
            [change[NSKeyValueChangeOldKey] getValue:&oldInset];
            
            CGPoint sameOffset = self.tableView.contentOffset;
            
            double delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"setting same offset = %@",  NSStringFromCGPoint(sameOffset));
                [self.tableView setContentOffset:sameOffset animated:NO];
            });
        }
    }
    NSLog(@"view frame=%@", NSStringFromCGRect(self.view.frame));
    NSLog(@"view bounds=%@", NSStringFromCGRect(self.view.bounds));
    NSLog(@"tableview frame=%@", NSStringFromCGRect(self.tableView.frame));
    NSLog(@"tableview bounds=%@", NSStringFromCGRect(self.tableView.bounds));
    UIEdgeInsets insets = self.tableView.contentInset;
    NSLog(@"inset frame= top %f left %f bottom %f right %f", insets.top, insets.left, insets.bottom, insets.right);
    NSLog(@"tableview contentSize=%@", NSStringFromCGSize(self.tableView.contentSize));
    NSLog(@"tableview contentOffset=%@", NSStringFromCGPoint(self.tableView.contentOffset));
    NSLog(@"\n");
    
    /*
    if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    */
}
/*
- (void)viewWillLayoutSubviews {
    NSLog(@"viewWillLayoutSubviews");
}
 */

#endif

#ifdef LATEST_SCROLL_BUGFIX

-(void)scrollSearchBarOffScreen {
    // scroll the search bar off-screen
    if (SEARCHBAR_SCROLLING_DEBUG) {
        NSLog(@"scrollSearchBarOffScreen: pos = %f, height=%f tv.top.y=%f, tv.height=%f inset.top=%f inset.botton=%f",self.tableView.contentOffset.y, self.tableView.contentSize.height, self.tableView.bounds.origin.y, self.tableView.bounds.size.height, self.tableView.contentInset.top, self.tableView.contentInset.bottom);
        NSLog(@"Nav frame=%@", NSStringFromCGRect(self.navigationController.navigationBar.frame));
        NSLog(@"Nav bounds=%@", NSStringFromCGRect(self.navigationController.navigationBar.bounds));
        NSLog(@"view frame=%@", NSStringFromCGRect(self.view.frame));
        NSLog(@"view bounds=%@", NSStringFromCGRect(self.view.bounds));
    }
    
    CGFloat visibleTop = self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height;
    CGFloat searchBarHeight = self.searchBar.bounds.size.height;
    //CGFloat startOfTable = -self.tableView.contentInset.top;
    
    CGFloat searchBarHiddenPos = searchBarHeight - visibleTop; // hidden = -24 , visible = -64
    
    CGFloat newPos = searchBarHiddenPos;
    CGPoint newOffset = CGPointMake(self.tableView.bounds.origin.x, newPos);
    if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"scrollSearchBarOffScreen: scrolling to pos = %f", newPos);
    self.tableView.contentOffset = newOffset;
    
}

-(void) adjustSearchBarPosition {
    CGFloat visibleTop = self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height;
    CGFloat searchBarHeight = self.searchBar.bounds.size.height;
    CGFloat searchBarHiddenPos = searchBarHeight - visibleTop; // typically -24
    CGFloat searchBarOpenPos = - visibleTop; // typically -64
    CGFloat currentPos = self.tableView.contentOffset.y;
    
    if (self.tableView.tableHeaderView != nil) {
        CGFloat threshhold = (searchBarHiddenPos + searchBarOpenPos)/2.0 - searchBarHeight/5.0;
        if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"adjustSearchBarPosition threshhold = %f", threshhold);
        if (currentPos < threshhold) { // threshhold on 75% open
            // is almost open, open completely
            if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"adjustSearchBarPosition moving to searchBarOpenPos = %f", searchBarOpenPos);
            [self.tableView setContentOffset:CGPointMake(0, searchBarOpenPos) animated:NO];
        } else if (currentPos < searchBarHiddenPos) {
            // is slightly open, close completely
            if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"adjustSearchBarPosition moving to searchBarHiddenPos = %f", searchBarHiddenPos);
            [self.tableView setContentOffset:CGPointMake(0, searchBarHiddenPos) animated:NO];
        } else {
            if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"adjustSearchBarPosition: not moving");
        }
    } else {
        // should not need to do anything, but wait
        if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"adjustSearchBarPosition: not moving, no searchbar");
    }
}

- (void)viewDidLayoutSubviews {
    if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"viewDidLayoutSubviews");
    [self adjustContentInset];
    //[self.tableView setContentOffset:self.tableView.contentOffset animated:false];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self adjustSearchBarPosition];
}

#endif

- (CGFloat)adjustContentInset {
    CGFloat visibleTop = self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height;
    //CGFloat bottom = self.tableView.bounds.size.height;
    
    CGFloat tabBarHeight = self.tabBarController.tabBar.frame.size.height;
    
    CGFloat searchBarHeight = self.searchBar.bounds.size.height;
    CGFloat searchBarHiddenPos = searchBarHeight - visibleTop;
    
    UIEdgeInsets newInsets = UIEdgeInsetsMake(visibleTop, 0, tabBarHeight, 0);
    UIEdgeInsets oldInsets = self.tableView.contentInset;
    
    if (newInsets.bottom != oldInsets.bottom || newInsets.left != oldInsets.left || newInsets.right != oldInsets.right || newInsets.top != oldInsets.top) {
        self.tableView.contentInset = UIEdgeInsetsMake(visibleTop, 0, tabBarHeight, 0);
    }
    
    return searchBarHiddenPos;
}




- (void)viewDidLoad {
    if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"ContactListViewController:viewDidLoad");
    
    [super viewDidLoad];

    [self registerCellClass: [self cellClass]];
    
    if (self.hasAddButton) {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd target: self action: @selector(addButtonPressed:)];
        self.navigationItem.rightBarButtonItem = addButton;
    }

#ifdef SEARCHBAR_SCROLLING_IN_HACK
    _correctContentOffset = self.tableView.contentOffset;
    [self.tableView addObserver:self forKeyPath:@"contentOffset" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [self.tableView addObserver:self forKeyPath:@"contentInset" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
    [self.tableView addObserver:self forKeyPath:@"contentSize" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
#endif
    
    [self setupTitle];

    if ( ! self.searchBar) {
        //self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, kMagicSearchBarHeight)];
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, kMagicSearchBarHeight-4)]; // for iPhone 5 this is the magic value
        self.tableView.tableHeaderView = self.searchBar;
    }
    self.searchBar.delegate = self;
    self.searchBar.placeholder = NSLocalizedString(@"search_placeholder", @"Contact List Search Placeholder");

    self.tableView.contentOffset = CGPointMake(0, [self adjustContentInset]); // adjustContentInset return search bar hidden offset
    
    self.keyboardHidingObserver = [AppDelegate registerKeyboardHidingOnSheetPresentationFor:self];

    self.tableView.rowHeight = [self calculateRowHeight];
    // Apple bug: Order matters. Setting the inset before the color leaves the "no cell separators" in the wrong color.
    self.tableView.separatorColor = [[HXOUI theme] tableSeparatorColor];
    self.tableView.separatorInset = self.cellPrototype.separatorInset;
#ifdef HIDE_SEPARATORS
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
#endif

    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];

    [self.tableView addSubview: self.placeholderView];

#ifdef SEARCHBAR_SCROLLING_IN_HACK_B
#endif
}

#ifdef SEARCHBAR_SCROLLING_IN_HACK_B

-(void) performDelayedScrollSearchBarOffScreen {
    if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"performDelayedScrollSearchBarOffScreen: pos = %f, height=%f tv.top.y=%f, tv.height=%f inset.top=%f inset.botton=%f",self.tableView.contentOffset.y, self.tableView.contentSize.height, self.tableView.bounds.origin.y, self.tableView.bounds.size.height, self.tableView.contentInset.top, self.tableView.contentInset.bottom);
    /*
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self scrollSearchBarOffScreen];
    });
     */
}

#endif

- (id) cellClass {
    return [ContactCell class];
}

- (void) setupTitle {
    if (self.hasGroupContactToggle) {
        self.groupContactsToggle = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"contact_list_nav_title", nil), NSLocalizedString(@"group_list_nav_title", nil)]];
        self.groupContactsToggle.selectedSegmentIndex = 0;
        [self.groupContactsToggle addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
        self.navigationItem.titleView = self.groupContactsToggle;
    }
    self.navigationItem.title = NSLocalizedString(@"contact_list_nav_title", nil);
}

- (CGFloat) calculateRowHeight {
    // XXX Note: The +1 magically fixes the layout. Without it the multiline
    // label in the conversation view is one pixel short and only fits one line
    // of text. I'm not sure if i'm compensating the separator (thus an apple
    // bug) or if it it is my fault.
    return ceilf([self.cellPrototype systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height) + 1;
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    [(id<ContactCell>)self.cellPrototype preferredContentSizeChanged: notification];
    self.tableView.rowHeight = [self calculateRowHeight];
    self.tableView.separatorInset = self.cellPrototype.separatorInset;
    [self.tableView reloadData];
}

- (void) segmentChanged: (id) sender {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactViewController:segmentChanged, sender= %@", sender);
    self.currentFetchedResultsController.delegate = nil;
    [self clearFetchedResultsControllers];
    [self.tableView reloadData];
    [self configurePlaceholder];
#ifdef LATEST_SCROLL_BUGFIX
    [self scrollSearchBarOffScreen];
#endif
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self.keyboardHidingObserver];
}

- (void) viewWillAppear:(BOOL)animated {
    if (VIEW_UPDATING_DEBUG) NSLog(@"ContactListViewController:viewWillAppear");
    self.currentFetchedResultsController.delegate = self;
    [self.currentFetchedResultsController performFetch:nil];
    [self.tableView reloadData];
    [super viewWillAppear: animated];
    [HXOBackend broadcastConnectionInfo];

    [self configurePlaceholder];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    if (VIEW_UPDATING_DEBUG) NSLog(@"ContactListViewController:viewDidAppear");
#ifdef SEARCHBAR_SCROLLING_IN_HACK_B
//    [self performDelayedScrollSearchBarOffScreen];
#endif
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear: animated];
    if (VIEW_UPDATING_DEBUG) NSLog(@"ContactListViewController:viewDidDisappear");
    //[self clearFetchedResultsControllers];
    self.currentFetchedResultsController.delegate = nil;
    if ([self isMovingFromParentViewController]) {
        if (VIEW_UPDATING_DEBUG) NSLog(@"isMovingFromParentViewController");
    }
    if ([self isBeingDismissed]) {
        if (VIEW_UPDATING_DEBUG) NSLog(@"isBeingDismissed");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.view endEditing:NO]; // hide keyboard on scrolling
}

bool almostEqual(CGFloat a, CGFloat b) {
    return abs(a - b) < 0.01;
}

#ifdef SEARCHBAR_SCROLLING_IN_HACK
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (SEARCHBAR_SCROLLING_DEBUG) NSLog(@"scrollViewDidScroll: pos = %f, height=%f tv.x=%f, tv.height=%f inset.top=%f inset.botton=%f",scrollView.contentOffset.y, scrollView.contentSize.height, self.tableView.bounds.origin.y, self.tableView.bounds.size.height, scrollView.contentInset.top, scrollView.contentInset.bottom);
    //NSLog(@"%@",[NSThread callStackSymbols]);
    
    /*
    //CGFloat searchBarHeight = self.searchBar.frame.size.height;
    CGFloat searchBarHeight = kMagicSearchBarHeight;
    if (scrollView.contentOffset.y >= searchBarHeight) {
        scrollView.contentInset = UIEdgeInsetsMake(-searchBarHeight, 0, 0, 0);
    } else {
        scrollView.contentInset = UIEdgeInsetsZero;
    }
     */
}
#endif

- (void) addButtonPressed: (id) sender {
    if (self.inGroupMode) {
        [self performSegueWithIdentifier: @"showGroup" sender: sender];
    } else {
        [self invitePeople];
    }
}

- (BOOL) inGroupMode {
    return self.groupContactsToggle && self.groupContactsToggle.selectedSegmentIndex == 1;
}

- (UITableViewCell*) cellPrototype {
     return [self prototypeCellOfClass: [self cellClass]];
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
    id cell = [tableView dequeueReusableCellWithIdentifier: [[self cellClass] reuseIdentifier] forIndexPath:indexPath];
    [self configureCell: cell atIndexPath: indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[section];
    return [sectionInfo name];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
    [self performSegueWithIdentifier: [contact.type isEqualToString: [Group entityName]] ? @"showGroup" : @"showContact" sender: indexPath];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ContactListController:prepareForSegue %@ sender %@", segue, sender);
    NSString * sid = [segue identifier];
    if ([sid isEqualToString: @"showGroup"] && [sender isEqual: self.navigationItem.rightBarButtonItem]) {
        DatasheetViewController * vc = [segue destinationViewController];
        vc.inspectedObject = [[GroupInStatuNascendi alloc] init];
    } else if ([sid isEqualToString:@"showContact"] || [sid isEqualToString: @"showGroup"]) {
        Contact * contact = [self.currentFetchedResultsController objectAtIndexPath: sender];
        DatasheetViewController * vc = [segue destinationViewController];
        vc.inspectedObject = contact;
    }
}

- (IBAction) unwindToRootView: (UIStoryboardSegue*) unwindSegue {
    NSLog(@"ContactListViewController:unwindToRootView");
}


#pragma mark - Search Bar

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self clearFetchedResultsControllers];
    [self.tableView reloadData];
}

#pragma mark - Fetched results controller


- (NSFetchedResultsController *)newFetchedResultsControllerWithSearch:(NSString *)searchString {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListController:newFetchedResultsControllerWithSearch %@", searchString);
    if (AppDelegate.instance.mainObjectContext == nil) {
        return nil;
    }
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: [self entityName] inManagedObjectContext: AppDelegate.instance.mainObjectContext];
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

    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest: fetchRequest
                                                                                                managedObjectContext: AppDelegate.instance.mainObjectContext
                                                                                                  sectionNameKeyPath: nil
                                                                                                           cacheName: nil];
    aFetchedResultsController.delegate = self;

    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return aFetchedResultsController;
}

- (NSArray*) sortDescriptors {
    return @[[[NSSortDescriptor alloc] initWithKey:@"relationshipState" ascending: YES],
             [[NSSortDescriptor alloc] initWithKey: @"alias" ascending: YES],
             [[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES]
             ];
}

- (void) addPredicates: (NSMutableArray*) predicates {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListController:addPredicates %@", predicates);
    if ([self.entityName isEqualToString: @"Contact"]) {
        [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@ AND (relationshipState == 'friend' OR relationshipState == 'blocked' OR relationshipState == 'kept' OR relationshipState == 'groupfriend' OR relationshipState == 'invited' OR relationshipState == 'invitedMe' OR isNearbyTag== 'YES')", [self entityName]]];
    } /* else {
       [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@", [self entityName]]];
    } */
}

- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListController:addPredicates %@", predicates);
    [predicates addObject: [NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@ OR alias CONTAINS[cd] %@", searchString, searchString]];
}

- (id) entityName {
    return self.inGroupMode ? [Group entityName] : [Contact entityName];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    _fetchedResultsController = [self newFetchedResultsControllerWithSearch: nil];
    return _fetchedResultsController;
}

- (NSFetchedResultsController *)searchFetchedResultsController {
    if (_searchFetchedResultsController != nil) {
        return _searchFetchedResultsController;
    }
    _searchFetchedResultsController = [self newFetchedResultsControllerWithSearch: self.searchBar.text];
    return _searchFetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"controllerWillChangeContent: %@",[NSThread callStackSymbols]);
    //if (FETCHED_RESULTS_DEBUG) NSLog(@"controllerWillChangeContent: %@ fetchRequest %@",controller, [controller fetchRequest]);
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@:controllerWillChangeContent", [self class]);
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
    if (FETCHED_RESULTS_DEBUG || FETCHED_RESULTS_DEBUG_PERF) {
        NSDictionary * changeTypeName = @{@(NSFetchedResultsChangeInsert):@"NSFetchedResultsChangeInsert",
                                          @(NSFetchedResultsChangeDelete):@"NSFetchedResultsChangeDelete",
                                          @(NSFetchedResultsChangeUpdate):@"NSFetchedResultsChangeUpdate",
                                          @(NSFetchedResultsChangeMove):@"NSFetchedResultsChangeMove"};
        
        
        //if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListViewController:NSFetchedResultsController: %@ fetchRequest %@ didChangeObject:class %@ ptr=%x path:%@ type:%@ newpath=%@",controller, [controller fetchRequest], [anObject class],(unsigned int)(__bridge void*)anObject,indexPath,changeTypeName[@(type)],newIndexPath);
        
        if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListViewController:NSFetchedResultsController: %@ didChangeObject:class %@ ptr=%x path:%@ type:%@ newpath=%@",controller, [anObject class],(unsigned int)(__bridge void*)anObject,indexPath,changeTypeName[@(type)],newIndexPath);
        //NSLog(@"ContactListViewController:NSFetchedResultsController:didChangeObject:%@ path:%@ type:%@ newpath=%@",anObject,indexPath,changeTypeName[@(type)],newIndexPath);
        NSLog(@"ContactListViewController:NSFetchedResultsController: %@",[NSThread callStackSymbols]);
    }
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
            //[self configureCell: [self.tableView cellForRowAtIndexPath:indexPath]
            //                   atIndexPath: newIndexPath ? newIndexPath : indexPath];
            {
                UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:indexPath];
                // cell is nil if not visible
                if (cell != nil) {
                    [self configureCell: cell atIndexPath: newIndexPath ? newIndexPath : indexPath];
                }
            }
            break;

        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }

    [self configurePlaceholder];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"controllerDidChangeContent: %@",[NSThread callStackSymbols]);
    //if (FETCHED_RESULTS_DEBUG) NSLog(@"controllerDidChangeContent %@ fetchRequest %@",controller, [controller fetchRequest]);
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@:controllerDidChangeContent", [self class]);
    NSDate * start = [NSDate new];
    [self.tableView endUpdates];
    NSDate * stop = [NSDate new];
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@:controllerDidChangeContent: updates took %1.3f", [self class], [stop timeIntervalSinceDate:start]);
}

- (void)configureCell: (ContactCell*) cell atIndexPath:(NSIndexPath *)indexPath {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ContactListViewController:configureCell %@ path %@, self class = %@",  [cell class],indexPath, [self class]);
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@",  [NSThread callStackSymbols]);
    Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];

    cell.delegate = nil;

    cell.titleLabel.text = contact.nickNameWithStatus;
    
    UIImage * avatar = contact.avatarImage;
    cell.avatar.image = avatar;
    cell.avatar.defaultIcon = [contact.type isEqualToString: [Group entityName]] ? [((Group*)contact).groupType isEqualToString: @"nearby"] ? [[avatar_location alloc] init] : [[avatar_group alloc] init] : [[avatar_contact alloc] init];
    cell.avatar.isBlocked = [contact isBlocked];
    cell.avatar.isPresent  = contact.isConnected && !contact.isKept;
    cell.avatar.isInBackground  = contact.isBackground;
    
    cell.subtitleLabel.text = [ContactListViewController statusStringForContact: contact];
}

+ (NSString*) statusStringForContact: (Contact*) contact {
    if ([contact isKindOfClass: [Group class]]) {
        // Man, this shit is disgusting. Needs de-monstering... I mean *really*. [agnat]
        Group * group = (Group*)contact;
        NSInteger joinedMemberCount = [group.otherJoinedMembers count];
        NSInteger invitedMemberCount = [group.otherInvitedMembers count];

        NSString * joinedStatus = @"";

        if (group.isKept) {
            joinedStatus = NSLocalizedString(@"group_state_kept", nil);
            
        } else if (group.myGroupMembership.isInvited){
            joinedStatus = NSLocalizedString(@"group_membership_state_invited", nil);
            
        } else {
            if (group.iAmAdmin) {
                joinedStatus = NSLocalizedString(@"group_membership_role_admin", nil);
            }
            if (joinedStatus.length>0) {
                joinedStatus = [joinedStatus stringByAppendingString: @", "];
            }
            joinedStatus =  [joinedStatus stringByAppendingString: [NSString stringWithFormat: HXOPluralocalizedString(@"group_member_count_joined", joinedMemberCount, YES), joinedMemberCount]];
            if (invitedMemberCount > 0) {
                if (joinedStatus.length>0) {
                    joinedStatus = [joinedStatus stringByAppendingString: @", "];
                }
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"group_member_invited_count",nil), invitedMemberCount];
            }
#ifdef DEBUG
            if (group.sharedKeyId != nil) {
                joinedStatus = [[joinedStatus stringByAppendingString:@" "] stringByAppendingString:group.sharedKeyIdString];
            }
#endif
        }
        return joinedStatus;
    } else {
        NSString * relationshipKey = [NSString stringWithFormat: @"contact_relationship_%@", contact.relationshipState];
        return NSLocalizedString(relationshipKey, nil);
    }
}

#pragma mark - Invitations

- (void) invitePeople {
    NSMutableArray * actions = [NSMutableArray array];
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            ((void(^)())actions[buttonIndex])(); // uhm, ok ... just call the damn thing, alright?
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"invite_option_sheet_title", @"Actionsheet Title")
                                        completionBlock: completion
                                      cancelButtonTitle: nil
                                 destructiveButtonTitle: nil
                                      otherButtonTitles: nil];


    if ([MFMessageComposeViewController canSendText]) {
        [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_sms_btn_title",@"Invite Actionsheet Button Title")];
        [actions addObject: ^() { [self inviteBySMS]; }];
    }
    if ([MFMailComposeViewController canSendMail]) {
        [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_mail_btn_title",@"Invite Actionsheet Button Title")];
        [actions addObject: ^() { [self inviteByMail]; }];
    }
    [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_code_btn_title",@"Invite Actionsheet Button Title")];
    [actions addObject: ^() { [self inviteByCode]; }];

    sheet.cancelButtonIndex = [sheet addButtonWithTitle: NSLocalizedString(@"cancel", nil)];

    [sheet showInView: self.view];
}

- (void) inviteByMail {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMailComposeViewController *picker= ((AppDelegate*)[UIApplication sharedApplication].delegate).mailPicker = [[MFMailComposeViewController alloc] init];
        picker.mailComposeDelegate = self;

        [picker setSubject: NSLocalizedString(@"invite_mail_subject", @"Mail Invitation Subject")];

        NSString * body = NSLocalizedString(@"invite_mail_body", @"Mail Invitation Body");
        NSString * inviteLink = [self inviteURL: token];
        NSString * appStoreLink = [self appStoreURL];
        //NSString * androidLink = [self androidURL];
        body = [NSString stringWithFormat: body, appStoreLink, /*androidLink,*/ inviteLink/*, token*/];
        [picker setMessageBody:body isHTML:NO];

        [self presentViewController: picker animated: YES completion: nil];
    }];
}

- (void) inviteBySMS {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMessageComposeViewController *picker= ((AppDelegate*)[UIApplication sharedApplication].delegate).smsPicker = [[MFMessageComposeViewController alloc] init];
        picker.messageComposeDelegate = self;

        NSString * smsText = NSLocalizedString(@"invite_sms_text", @"SMS Invitation Body");
        picker.body = [NSString stringWithFormat: smsText, [self inviteURL: token], [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName]];

        [self presentViewController: picker animated: YES completion: nil];

    }];
}

- (void) inviteByCode {
    [self performSegueWithIdentifier: @"showInviteCodeViewController" sender: self];
}

- (NSString*) inviteURL: (NSString*) token {
    return [NSString stringWithFormat: @"%@://%@", kHXOURLScheme, token];
}

- (NSString*) appStoreURL {
    return @"itms-apps://itunes.com/apps/hoccerxo";
}

- (NSString*) androidURL {
    return @"http://google.com";
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {

	switch (result) {
		case MFMailComposeResultCancelled:
			break;
		case MFMailComposeResultSaved:
			break;
		case MFMailComposeResultSent:
			break;
		case MFMailComposeResultFailed:
            NSLog(@"mailComposeControllerr:didFinishWithResult MFMailComposeResultFailed");
			break;
		default:
			break;
	}
    [self dismissViewControllerAnimated: NO completion: nil];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result {

	switch (result) {
		case MessageComposeResultCancelled:
			break;
		case MessageComposeResultSent:
			break;
		case MessageComposeResultFailed:
            NSLog(@"messageComposeViewController:didFinishWithResult MessageComposeResultFailed");
			break;
		default:
			break;
	}
    [self dismissViewControllerAnimated: NO completion: nil];
}

#pragma mark - Empty Table Placeholder

- (UIView*) placeholderView {
    if ( ! _placeholderView) {
        CGFloat h = self.view.bounds.size.height - (self.view.bounds.origin.y + 50);
        _placeholderView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.view.bounds.size.width, h)];
        _placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        [_placeholderView addSubview: self.placeholderImageView];
        [_placeholderView addSubview: self.placeholderLabel];

        NSDictionary * views = @{@"image": self.placeholderImageView, @"label": self.placeholderLabel};
        NSString * format = [NSString stringWithFormat: @"H:|-[image]-|"];
        [_placeholderView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

        format = [NSString stringWithFormat: @"H:|-[label]-|"];
        [_placeholderView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

        format = [NSString stringWithFormat: @"V:|-(%f)-[image]-(%f)-[label]-(>=%f)-|", 8 * kHXOGridSpacing, 4 * kHXOGridSpacing, kHXOGridSpacing];
        [_placeholderView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
    }
    return _placeholderView;
}

- (UIImageView*) placeholderImageView {
    if ( ! _placeholderImageView) {
        _placeholderImageView = [[UIImageView alloc] initWithFrame: CGRectZero];
        _placeholderImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderImageView.contentMode = UIViewContentModeCenter;
    }
    return _placeholderImageView;
}

- (HXOHyperLabel*) placeholderLabel {
    if ( ! _placeholderLabel) {
        _placeholderLabel = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
        _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderLabel.textColor = [HXOUI theme].tablePlaceholderTextColor;
        _placeholderLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleCaption1];
        _placeholderLabel.textAlignment = NSTextAlignmentCenter;
        _placeholderLabel.delegate = self;
    }
    return _placeholderLabel;
}

- (void) configurePlaceholder {
    BOOL wasShowingPlaceHolder = self.placeholderView.alpha == 1;
    BOOL hadTableHeader = self.tableView.tableHeaderView != nil;
    
    self.placeholderLabel.attributedText = [self placeholderText];
    self.placeholderImageView.image = [self placeholderImage];
    
    BOOL isEmpty = [self tableViewIsEmpty];
    if (wasShowingPlaceHolder != isEmpty) {
        if (SEPERATOR_DEBUG) NSLog(@"Changing place holder from %d -> %d", wasShowingPlaceHolder, isEmpty);
        self.placeholderView.alpha = isEmpty ? 1 : 0;
    }
    if (hadTableHeader == isEmpty) {
        if (SEPERATOR_DEBUG) NSLog(@"Changing table header from %d -> %d", hadTableHeader, isEmpty);
        self.tableView.tableHeaderView = isEmpty ? nil : self.searchBar;
    }
    
#ifdef LATEST_SCROLL_BUGFIX
    if (wasShowingPlaceHolder && !isEmpty) {
        [self scrollSearchBarOffScreen];
    }
#endif

#ifdef SEARCHBAR_SCROLLING_IN_HACK
    // This is hack #3 which helps hack #2 to detect that
    // the content offset has silently been changed
   if (SEARCHBAR_SCROLLING_DEBUG)  NSLog(@"configurePlaceholder: resetting content offset");
   // [self.tableView setContentOffset:self.tableView.contentOffset];
#endif
}

- (BOOL) tableViewIsEmpty {
    for (int i = 0; i < [self numberOfSectionsInTableView: self.tableView]; ++i) {
        if ([self tableView: self.tableView numberOfRowsInSection: i] > 0) {
            return NO;
        }
    }
    return YES;
}

- (NSAttributedString*) placeholderText {
    return HXOLocalizedStringWithLinks(self.inGroupMode ? @"group_list_placeholder" : @"contact_list_placeholder", nil);
}

- (UIImage*) placeholderImage {
    return [UIImage imageNamed: self.inGroupMode ? @"placeholder-groups" : @"placeholder-chats"];
}

- (void) hyperLabel: (HXOHyperLabel*) label didPressLink: (id) link long: (BOOL) longPress {
    ((WebViewController*)self.webViewController.viewControllers[0]).homeUrl = link;
    [self.navigationController presentViewController: self.webViewController animated: YES completion: nil];
}

- (UINavigationController*) webViewController {
    if ( ! _webViewController) {
        _webViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"webViewController"];
    }
    return _webViewController;
}

#pragma mark - Attic

@synthesize chatBackend = _chatBackend;
- (HXOBackend*) chatBackend {
    if ( ! _chatBackend) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

@end
