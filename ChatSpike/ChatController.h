//
//  ChatController.h
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface ChatController : NSObject <UITableViewDataSource>
{
    NSPersistentStoreCoordinator * persistentStoreCoordinator;
    NSManagedObjectModel * managedObjectModel;
    NSManagedObjectContext * managedObjectContext;
}

@property (nonatomic, retain) NSMutableArray * chatMessages;

- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *) managedObjectContext;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSString *)applicationDocumentsDirectory;

- (void) addMessage: (NSString*) text;

@end
