//
//  ContactListViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TableViewControllerWithPlaceholder.h"

@interface ContactListViewController : TableViewControllerWithPlaceholder <NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@property (nonatomic,strong) IBOutlet UISearchBar* searchBar;

@end
