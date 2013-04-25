//
//  AppDelegate.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkBackend.h"

@class ConversationViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, HoccerTalkDelegate>
{
    UIBackgroundTaskIdentifier _backgroundTask;
}
@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong) HoccerTalkBackend * chatBackend;
@property (nonatomic, strong) UINavigationController * navigationController;
@property (nonatomic, strong) ConversationViewController * conversationViewController;

@property (nonatomic, strong) NSString * userAgent;

- (void)saveContext;
- (void)saveDatabase;
- (NSURL *)applicationDocumentsDirectory;
- (void) setupDone: (BOOL) performRegistration;

@end
