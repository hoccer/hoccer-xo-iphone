//
//  ChatController.m
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ChatController.h"
#import "ChatMessage.h"
#import "ChatCell.h"
#import "Contact.h"

@implementation ChatController

@synthesize tableView;

- (id) init {
    self = [super init];
    if (self != nil) {

        [self insertDummies: 5000];

        // TODO: create fetched results controller lazily
		NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"ChatMessage" inManagedObjectContext: self.managedObjectContext];
		[fetchRequest setEntity:entity];
        [fetchRequest setFetchBatchSize:20];
		
		// Order the events by creation date, most recent last.
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"creationDate" ascending: YES];
		NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
		[fetchRequest setSortDescriptors:sortDescriptors];

        resultController = [[NSFetchedResultsController alloc]
                                initWithFetchRequest: fetchRequest
                                managedObjectContext: self.managedObjectContext
                                sectionNameKeyPath:nil
                                cacheName:@"ChatMessageCache"];
        resultController.delegate = self;

        NSError *error;
        BOOL success = [resultController performFetch:&error];
        if ( ! success) {
            NSLog(@"Error fetching chat messages: %@", error);
        }

        myAvatar = [UIImage imageNamed: @"azrael.png"];
        myNick = @"Azrael";
    }
    return self;
}

- (void) addMessage: (NSString*) text {
	ChatMessage * message =  (ChatMessage*)[NSEntityDescription insertNewObjectForEntityForName:@"ChatMessage" inManagedObjectContext: self.managedObjectContext];
	
    message.text = text;
    message.creationDate = [NSDate date]; // XXX use server time
    
	NSError *error;
	[managedObjectContext save:&error];
    if (error != nil) {
        NSLog(@"ERROR - failed to save message: %@", error);
    }
}

- (unsigned long) messageCount {
    return [resultController.fetchedObjects count];
}

- (void) insertDummies: (unsigned long) total {

    NSArray * nicks    = @[ @"Schlumpfine", @"Daddy S" ];
    NSArray * avatars  = @[ @"schlumpf_schlumpfine.jpg", @"schlumpf_papa.jpg" ];

    NSManagedObjectContext *importContext = [[NSManagedObjectContext alloc] init];
    [importContext setPersistentStoreCoordinator: self.persistentStoreCoordinator];
    [importContext setUndoManager:nil];

    NSFetchRequest *contactRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * contactEntity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext: importContext];
    [contactRequest setEntity:contactEntity];

    NSError *error;
    unsigned long contactCount = [importContext countForFetchRequest: contactRequest error: &error];
    if (contactCount == 0) {
        [self createDirectory: @"avatars" atFilePath: [self applicationDocumentsDirectory]];
        int index = 0;
        for (NSString* avatar in avatars) {

            UIImage * image = [UIImage imageNamed: avatar];
            NSData *imgData = UIImageJPEGRepresentation(image, 1);

            NSString  *path = [[[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"avatars"] stringByAppendingPathComponent: avatar];
            [imgData writeToFile: path atomically:YES];
            NSURL * url = [NSURL fileURLWithPath: path];
            NSString * nick = [nicks objectAtIndex: index++];

            Contact * contact =  (Contact*)[NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext: importContext];

            contact.nickName = nick;
            contact.avatarURL = [url absoluteString];
        }
        [importContext save:&error];
        if (error != nil) {
            NSLog(@"ERROR - failed to save message: %@", error);
        }
    }
    NSArray * contacts = [importContext executeFetchRequest: contactRequest error: &error];

    NSArray * messages = @[ @"Käffchen?"
                        , @"k, bin in 10min da..."
                        , @"bis gloich"
                        , @"Was geht heute abend?"
                        , @"bin schon verabredet. Aber wir könnten am WE einen trinken gehen. In der Panke ist irgendwie HipHop party... Backyard Joints"
                        , @"Mein Router ist abgeraucht :-/. Kannst Du ein ordentliches DSL Modem empfehlen?"
                        , @"Ich würde mal bei den Fritzboxen von AVM gucken. Das ist echt ordentliche Hardware."
                        , @"Check mal deine mail..."
                        , @"kewl! Will ich haben."
                        ];

    NSFetchRequest *messageRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * messageEntity = [NSEntityDescription entityForName:@"ChatMessage" inManagedObjectContext: importContext];
    [messageRequest setEntity:messageEntity];

    unsigned long messageCount = [importContext countForFetchRequest: messageRequest error: &error];

    if (messageCount >= total) {
        return;
    }

    do {
        ChatMessage * message =  (ChatMessage*)[NSEntityDescription insertNewObjectForEntityForName:@"ChatMessage" inManagedObjectContext: importContext];

        message.text = [messages objectAtIndex: messageCount % messages.count];
        message.creationDate = [NSDate date];
        if (messageCount % 2 == 0) {
            message.contact = [contacts objectAtIndex: 0];
            //NSLog(@"contact %@", message.contact);
        } else {
            //NSLog(@"no contact %@", message.contact);
        }
    } while (++messageCount < total);

    [importContext save:&error];
    if (error != nil) {
        NSLog(@"ERROR - failed to save message: %@", error);
    }

}

- (NSArray*) createDummyContacts {

    NSArray * nicks    = @[ @"Schlumpfine", @"Daddy S" ];
    NSArray * avatars  = @[ @"schlumpf_schlumpfine.jpg", @"schlumpf_papa.jpg" ];

    [self createDirectory: @"avatars" atFilePath: [self applicationDocumentsDirectory]];

    NSManagedObjectContext *importContext = [[NSManagedObjectContext alloc] init];
    [importContext setPersistentStoreCoordinator: self.persistentStoreCoordinator];
    [importContext setUndoManager:nil];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext: importContext];
    [fetchRequest setEntity:entity];

    NSError *error;
    unsigned long count = [importContext countForFetchRequest: fetchRequest error: &error];

    if (count < [nicks count]) {
        int index = 0;
        for (NSString* avatar in avatars) {
            UIImage * image = [UIImage imageNamed: avatar];
            NSData *imgData = UIImageJPEGRepresentation(image, 1);

            NSString  *path = [[[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"avatars"] stringByAppendingPathComponent: avatar];

            [imgData writeToFile: path atomically:YES];
            NSURL * url = [NSURL fileURLWithPath: path];
            NSString * nick = [nicks objectAtIndex: index++];

            Contact * contact =  (Contact*)[NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext: importContext];

            contact.nickName = nick;
            contact.avatarURL = [url absoluteString];
        }
        [importContext save:&error];
        if (error != nil) {
            NSLog(@"ERROR - failed to save message: %@", error);
        }
    }
    return [importContext executeFetchRequest: fetchRequest error: &error];
}

-(void)createDirectory:(NSString *)directoryName atFilePath:(NSString *)filePath
{
    NSString *filePathAndDirectory = [filePath stringByAppendingPathComponent:directoryName];
    NSError *error;

    if (![[NSFileManager defaultManager] createDirectoryAtPath:filePathAndDirectory
                                   withIntermediateDirectories:NO
                                                    attributes:nil
                                                         error:&error])
    {
        NSLog(@"Create directory error: %@", error);
    }
}

#pragma mark Fetched Results Controller

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self configureCell: (ChatCell*)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [tableView endUpdates];
}

/*
 // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.

 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
 {
 // In the simplest, most efficient, case, reload the table view.
 [self.tableView reloadData];
 }
 */


#pragma mark Core Data Stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *) managedObjectContext {
	
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return managedObjectContext;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:@"ChatSpikeModel" ofType:@"momd"];
    NSURL *momURL = [NSURL fileURLWithPath:path];
    managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
	
    NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"ChatMessage.sqlite"]];
	
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    
	NSError *error;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error]) {
		//NSLog(@"error: %@", error);
	}
	
    return persistentStoreCoordinator;
}

/**
 Returns the path to the application's documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

#pragma mark Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[resultController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	id <NSFetchedResultsSectionInfo> sectionInfo = [[resultController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ChatCell *cell = (ChatCell*)[aTableView dequeueReusableCellWithIdentifier: [ChatCell reuseIdentifier]];
    if (cell == nil) {
        cell = [ChatCell cell];
    }
    
    [self configureCell: cell atIndexPath: indexPath];
    return cell;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ChatMessage * msg = [resultController objectAtIndexPath:indexPath];
    return [ChatCell heightForText: msg.text];
}


- (void)configureCell:(ChatCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    ChatMessage * msg = [resultController objectAtIndexPath:indexPath];
    [cell layout: msg.contact != nil];
    cell.messageText = msg.text;
    cell.nickName = msg.contact != nil ? msg.contact.nickName : myNick;
    if ( ! msg.contact) {
        cell.avatar = myAvatar;
    }
}


@end
