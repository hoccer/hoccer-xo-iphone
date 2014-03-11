//
//  ContactListViewController.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HXOTableViewController.h"

@class ContactCell;

@interface ContactListViewController : HXOTableViewController <NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@property (nonatomic, readonly) UISearchBar *                searchBar;
@property (nonatomic, readonly) NSFetchedResultsController * currentFetchedResultsController;
@property (nonatomic, assign)   BOOL                         hasAddButton;
@property (nonatomic, assign)   BOOL                         hasGroupContactToggle;
@property (nonatomic,strong)    UISegmentedControl *         groupContactsToggle;

- (void) clearFetchedResultsControllers;
- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)cell
                     atIndexPath:(NSIndexPath *)indexPath;

- (id) entityName;
- (NSArray*) sortDescriptors;
- (void) addPredicates: (NSMutableArray*) predicates;
- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString;
- (UITableViewCell*) prototypeCell;

@end
