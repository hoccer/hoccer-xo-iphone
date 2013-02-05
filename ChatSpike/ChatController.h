//
//  ChatController.h
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface ChatController : NSObject <UITableViewDataSource, NSFetchedResultsControllerDelegate>
{
    NSPersistentStoreCoordinator * persistentStoreCoordinator;
    NSManagedObjectModel * managedObjectModel;
    NSManagedObjectContext * managedObjectContext;
    NSFetchedResultsController * resultController;
}

@property (nonatomic, retain) UITableView * tableView;

- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *) managedObjectContext;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSString *)applicationDocumentsDirectory;

- (void) addMessage: (NSString*) text;
- (unsigned long) messageCount;

@end
