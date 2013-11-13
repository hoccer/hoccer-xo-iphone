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
@class MFSideMenuContainerViewController;

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

@property (nonatomic, strong) NSString * userAgent;

@property (nonatomic, strong)  GCNetworkReachability * internetReachabilty;

@property (strong, nonatomic)  NSDate * lastDatebaseSaveDate;
@property (strong, nonatomic)  NSTimer * nextDatabaseSaveTimer;


@property BOOL launchedAfterCrash;
@property BOOL runningNewBuild;

- (void)saveContext;
- (void)saveDatabase;

- (NSURL *)applicationDocumentsDirectory;
- (NSURL *)applicationLibraryDirectory;
- (void) setupDone: (BOOL) performRegistration;
- (void) showCorruptedDatabaseAlert;

-(void) dumpAllRecordsOfEntityNamed:(NSString *)theEntityName;


+ (void) setDefaultAudioSession;
+ (void) setRecordingAudioSession;
+ (void) setMusicAudioSession;
+ (void) setProcessingAudioSession;

+ (id) registerKeyboardHidingOnSheetPresentationFor:(UIViewController*)controller;

+ (void) updateStatusbarForViewController:(UIViewController*)viewcontroller style:(UIStatusBarStyle)theStyle;
+ (void) setBlackFontStatusbarForViewController:(UIViewController*)viewcontroller;
+ (void) setWhiteFontStatusbarForViewController:(UIViewController*)viewcontroller;

@end
