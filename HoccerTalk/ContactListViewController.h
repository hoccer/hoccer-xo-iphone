//
//  MasterViewController.h
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ChatViewController;

#import <CoreData/CoreData.h>

@interface ContactListViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) ChatViewController *chatViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
