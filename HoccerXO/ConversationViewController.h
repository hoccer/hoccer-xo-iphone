//
//  MasterViewController.h
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class ChatViewController;


@interface ConversationViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) ChatViewController *chatViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
