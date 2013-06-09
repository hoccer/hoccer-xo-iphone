//
//  AppDelegate.h
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOBackend.h"
#import "GCNetworkReachability.h"

@class ConversationViewController;
#ifdef NEW_MFSIDEMENU
@class MFSideMenuContainerViewController;
#endif

@interface AppDelegate : UIResponder <UIApplicationDelegate, HXODelegate, UIAlertViewDelegate>
{
    UIBackgroundTaskIdentifier _backgroundTask;
}
@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (readonly, strong, nonatomic) NSManagedObjectModel *rpcObjectModel;

@property (nonatomic, strong) HXOBackend * chatBackend;
@property (nonatomic, strong) UINavigationController * navigationController;
@property (nonatomic, strong) ConversationViewController * conversationViewController;

#ifdef NEW_MFSIDEMENU
@property (nonatomic, strong) MFSideMenuContainerViewController * menuContainerViewController;
#endif

@property (nonatomic, strong) NSString * userAgent;

@property (nonatomic, strong)  GCNetworkReachability * internetReachabilty;

- (void)saveContext;
- (void)saveDatabase;
- (void)pauseDatabaseSaving;
- (void)resumeDatabaseSaving;

- (NSURL *)applicationDocumentsDirectory;
- (void) setupDone: (BOOL) performRegistration;
- (void) showCorruptedDatabaseAlert;

+ (void) setDefaultAudioSession;
+ (void) setRecordingAudioSession;
+ (void) setMusicAudioSession;
+ (void) setProcessingAudioSession;


@end
