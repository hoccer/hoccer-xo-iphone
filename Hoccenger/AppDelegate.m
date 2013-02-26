//
//  AppDelegate.m
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AppDelegate.h"

#import "ContactListViewController.h"
#import "Contact.h"
#import "Message.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self insertDummies: 5000];

    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)navigationController.topViewController;
        
        UINavigationController *masterNavigationController = splitViewController.viewControllers[0];
        ContactListViewController *controller = (ContactListViewController *)masterNavigationController.topViewController;
        controller.managedObjectContext = self.managedObjectContext;
    } else {
        UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
        ContactListViewController *controller = (ContactListViewController *)navigationController.topViewController;
        controller.managedObjectContext = self.managedObjectContext;
    }
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Hoccenger" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Hoccenger.sqlite"];
    
    NSError *error = nil;

    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void) insertDummies: (unsigned long) messageCount {

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
        int index = 0;
        for (NSString* avatar in avatars) {

            Contact * contact =  (Contact*)[NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext: importContext];
            contact.nickName = [nicks objectAtIndex: index++];
            contact.avatar = UIImageJPEGRepresentation([UIImage imageNamed: avatar], 1.0);
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
                            , @"bin schon verabredet. Aber wir könnten am WE einen trinken gehen. In der Panke ist irgendwie HipHop party... Backyard Joints. Lorem ipsum blah fasel blub..."
                            , @"Mein Router ist abgeraucht :-/. Kannst Du ein ordentliches DSL Modem empfehlen?"
                            , @"Ich würde mal bei den Fritzboxen von AVM gucken. Das ist echt ordentliche Hardware."
                            , @"Check mal deine mail..."
                            , @"kewl! Will ich haben."
                            ];

    NSFetchRequest *messageRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * messageEntity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext: importContext];
    [messageRequest setEntity:messageEntity];

    unsigned long count = [importContext countForFetchRequest: messageRequest error: &error];

    if (count >= messageCount) {
        return;
    }

    do {
        Message * message =  (Message*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext: importContext];

        message.text = [messages objectAtIndex: count % messages.count];
        message.timeStamp = [NSDate date];
        message.contact = [contacts objectAtIndex: 0];
        message.isOutgoing = [NSNumber numberWithBool: count % 2 == 0 ? NO : YES];
    } while (++count < messageCount);

    [importContext save:&error];
    if (error != nil) {
        NSLog(@"ERROR - failed to save message: %@", error);
    }
    
}

@end
