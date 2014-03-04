//
//  AppDelegate.h
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>

#import "HXOBackend.h"
#import "GCNetworkReachability.h"

typedef void(^StringEntryCompletion)(NSString* entry);

@class ConversationViewController;
@class MFSideMenuContainerViewController;
@class HTTPServer;

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

@property (nonatomic, strong) NSString * userAgent;

@property (nonatomic, strong)  GCNetworkReachability * internetReachabilty;

@property (strong, nonatomic)  NSDate * lastDatebaseSaveDate;
@property (strong, nonatomic)  NSTimer * nextDatabaseSaveTimer;

@property (nonatomic, strong) NSURL * openedFileURL;
@property (nonatomic, strong) NSString * openedFileName;
@property (nonatomic, strong) NSString * openedFileDocumentType;
@property (nonatomic, strong) NSString * openedFileMediaType;
@property (nonatomic, strong) NSString * openedFileMimeType;


@property (nonatomic,readonly) ABPeoplePickerNavigationController * peoplePicker;

#ifdef WITH_WEBSERVER
@property (readonly,nonatomic, strong) HTTPServer *httpServer;

- (void)startHttpServer;
- (void)stopHttpServer;
- (BOOL)httpServerIsRunning;
#endif

@property BOOL launchedAfterCrash;
@property BOOL runningNewBuild;

@property (nonatomic, strong) MFMessageComposeViewController *smsPicker;
@property (nonatomic, strong) MFMailComposeViewController *mailPicker;


- (void)saveContext;
- (void)saveDatabase;

- (NSURL *)applicationDocumentsDirectory;
- (NSURL *)applicationLibraryDirectory;
- (void) setupDone: (BOOL) performRegistration;
- (void) showCorruptedDatabaseAlert;

-(void) dumpAllRecordsOfEntityNamed:(NSString *)theEntityName;

- (void) showFatalErrorAlertWithMessage:(NSString *)message withTitle:(NSString *)title;
    
+ (void) setDefaultAudioSession;
+ (void) setRecordingAudioSession;
+ (void) setMusicAudioSession;
+ (void) setProcessingAudioSession;
+ (void) requestRecordPermission;

+ (id) registerKeyboardHidingOnSheetPresentationFor:(UIViewController*)controller;

+ (void) updateStatusbarForViewController:(UIViewController*)viewcontroller style:(UIStatusBarStyle)theStyle;
+ (void) setBlackFontStatusbarForViewController:(UIViewController*)viewcontroller;
+ (void) setWhiteFontStatusbarForViewController:(UIViewController*)viewcontroller;


+ (void) showErrorAlertWithMessage: (NSString *) message withTitle:(NSString *) title;
+ (void) showErrorAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title;

+ (void) showAlertWithMessage: (NSString *) message withTitle:(NSString *) title withArgument:(NSString*) argument;
+ (void) showAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title withArgument:(NSString*) argument;

+ (void) enterStringAlert: (NSString *) message withTitle:(NSString *)title withPlaceHolder:(NSString *)placeholder onCompletion:(StringEntryCompletion)completionBlock;

+ (NSString *)uniqueFilenameForFilename: (NSString *)theFilename inDirectory: (NSString *)directory;
+ (NSString *)sanitizeFileNameString:(NSString *)fileName;
+ (NSURL *)uniqueNewFileURLForFileLike:(NSString *)fileNameHint;

- (NSString *)ownIPAddress:(BOOL)preferIPv4;
- (NSDictionary *)ownIPAddresses;

- (void) jumpToChat: (Contact*) contact;

+ (AppDelegate*)instance;


@end
