//
//  ContactListViewController.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>


@class ContactCell;

@interface ContactListViewController : UITableViewController <NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@property (nonatomic,strong) IBOutlet UISearchBar* searchBar;
@property (nonatomic, readonly) NSFetchedResultsController * currentFetchedResultsController;

- (void) clearFetchedResultsControllers;
- (void)fetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
                   configureCell:(ContactCell *)cell
                     atIndexPath:(NSIndexPath *)indexPath;
@end
