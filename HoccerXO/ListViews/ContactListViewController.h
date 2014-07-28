//
//  ContactListViewController.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

#import "HXOTableViewController.h"
#import "HXOHyperLabel.h"

@class Contact;

@interface ContactListViewController : HXOTableViewController <NSFetchedResultsControllerDelegate, UISearchBarDelegate, HXOHyperLabelDelegate>



@property (nonatomic, strong) IBOutlet UISearchBar         * searchBar;
@property (nonatomic, readonly) NSFetchedResultsController * currentFetchedResultsController;
@property (nonatomic, assign)   BOOL                         hasAddButton;
@property (nonatomic, assign)   BOOL                         hasGroupContactToggle;

@property (nonatomic,strong)    UISegmentedControl          * groupContactsToggle;

- (void) clearFetchedResultsControllers;
- (void) configureCell: (id) cell atIndexPath:(NSIndexPath *)indexPath;

- (id) entityName;
- (NSArray*) sortDescriptors;
- (void) addPredicates: (NSMutableArray*) predicates;
- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString;

- (id) cellClass;
- (void) invitePeople;
- (void) addButtonPressed: (id) sender;
- (void) segmentChanged: (id) sender;

+ (NSString*) statusStringForContact: (Contact*) contact;

@end
