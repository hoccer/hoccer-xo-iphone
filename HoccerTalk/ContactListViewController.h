//
//  ContactListViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ConversationViewController;
@class MFSideMenu;

@interface ContactListViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic,strong) IBOutlet UISearchBar* searchBar;

@property (nonatomic, assign) ConversationViewController * conversationViewController;
@property (nonatomic, assign) MFSideMenu *sideMenu;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
