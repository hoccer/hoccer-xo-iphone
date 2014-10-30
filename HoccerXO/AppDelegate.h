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


FOUNDATION_EXPORT NSString * const kHXOURLScheme;
FOUNDATION_EXPORT NSString * const kHXOTransferCredentialsURLImportScheme;
FOUNDATION_EXPORT NSString * const kHXOTransferCredentialsURLCredentialsHost;
FOUNDATION_EXPORT NSString * const kHXOTransferCredentialsURLArchiveHost;
FOUNDATION_EXPORT NSString * const kHXOTransferCredentialsURLExportScheme;
FOUNDATION_EXPORT NSString * const kHXOTransferArchiveUTI;
FOUNDATION_EXPORT NSString * const kHXODefaultArchiveName;

typedef void (^ContinueBlock)();
typedef void (^ContextBlock)(NSManagedObjectContext* context);
typedef void (^ContextParameterBlock)(NSManagedObjectContext* context, NSArray * managedObjects);

extern NSArray * objectIds(NSArray* managedObjects);
extern NSArray * permanentObjectIds(NSArray* managedObjects);
extern NSArray * managedObjects(NSArray* objectIds, NSManagedObjectContext * context);
extern NSArray * existingManagedObjects(NSArray* objectIds, NSManagedObjectContext * context);

@class ConversationViewController;
@class MFSideMenuContainerViewController;
@class HTTPServer;

@interface AppDelegate : UIResponder <UIApplicationDelegate, HXODelegate, UIAlertViewDelegate, UITabBarControllerDelegate,UIDocumentInteractionControllerDelegate>
{
    UIBackgroundTaskIdentifier _backgroundTask;
}
@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *mainObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectContext *currentObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (readonly, strong, nonatomic) NSManagedObjectModel *rpcObjectModel;

@property (nonatomic, strong) HXOBackend * chatBackend;

@property (nonatomic, strong) NSString * userAgent;

@property (nonatomic, strong)  GCNetworkReachability * internetReachabilty;

@property (strong, nonatomic)  NSDate * lastDatebaseSaveDate;
@property (strong, nonatomic)  NSTimer * nextDatabaseSaveTimer;

@property (strong, nonatomic)  NSDate * lastPendingChangesProcessed;
@property (strong, nonatomic)  NSTimer * nextChangeProcessTimer;

@property (nonatomic, strong) NSURL * openedFileURL;
@property (nonatomic, strong) NSString * openedFileName;
@property (nonatomic, strong) NSString * openedFileDocumentType;
@property (nonatomic, strong) NSString * openedFileMediaType;
@property (nonatomic, strong) NSString * openedFileMimeType;

@property (readonly) BOOL inNearbyMode;


@property (nonatomic,readonly) ABPeoplePickerNavigationController * peoplePicker;

@property (nonatomic, strong) UIDocumentInteractionController * interactionController;


#ifdef WITH_WEBSERVER
@property (readonly,nonatomic, strong) HTTPServer *httpServer;

- (void)startHttpServer;
- (void)stopHttpServer;
- (BOOL)httpServerIsRunning;
#endif

@property BOOL launchedAfterCrash;
@property BOOL runningNewBuild;

@property (nonatomic, strong) ConversationViewController * conversationViewController;


- (void)saveContext;
- (void)saveDatabase;
-(void)saveContext:(NSManagedObjectContext*)context;
- (BOOL)deleteObject:(id)object;
- (BOOL)deleteObject:(id)object inContext:(NSManagedObjectContext *) context;

- (void)performWithLockingId:(const NSString*)lockId inNewBackgroundContext:(ContextBlock)backgroundBlock;
- (void)performWithoutLockingInNewBackgroundContext:(ContextBlock)backgroundBlock;
- (void)performWithoutLockingInMainContext:(ContextBlock)contextBlock;
- (void)performAfterCurrentContextFinishedInMainContext:(ContextBlock)contextBlock;
- (void)performAfterCurrentContextFinishedInMainContextPassing:(NSArray*)objects withBlock:(ContextParameterBlock)contextBlock;
//- (void)lockId:(NSString*)Id;
//- (void)unlockId:(NSString*)Id;
- (void)assertMainContext;

- (NSURL *)applicationDocumentsDirectory;
- (NSURL *)applicationLibraryDirectory;
- (void) setupDone: (BOOL) performRegistration;
- (void) showCorruptedDatabaseAlert;
- (void) showInvalidCredentialsWithInfo:(NSString*)info withContinueHandler:(ContinueBlock)onNotDeleted;
- (void) showLoginFailedWithInfo:(NSString*)info withContinueHandler:(ContinueBlock)onContinue;

-(void) dumpAllRecordsOfEntityNamed:(NSString *)theEntityName;

- (void) showFatalErrorAlertWithMessage:(NSString *)message withTitle:(NSString *)title;
- (void) showOperationFailedAlert:(NSString *)message withTitle:(NSString *) title withOKBlock:(ContinueBlock)okBlock;

-(void)configureForNearbyMode:(BOOL)modeNearby;
-(BOOL)inNearbyMode;

-(void)beginInspecting:(id)inspectedObject withInspector:(id)inspector;
-(void)endInspecting:(id)inspectedObject withInspector:(id)inspector;
-(BOOL)isInspecting:(id)inspectedObject withInspector:(id)inspector;
-(BOOL)isInspecting:(id)inspectedObject;
-(id)inspectorOf:(id)inspectedObject;

- (NSURL*)makeArchive:(NSURL*)archiveURL;
- (void) makeArchive:(NSURL*)archiveURL withHandler:(URLResultHandler)onReady;
- (void) importArchive:(NSURL*)archiveURL withHandler:(GenericResultHandler)onReady;
- (BOOL)extractArchive:(NSURL*)archiveURL;

+ (UIViewController*) getTopMostViewController;
- (BOOL) openWithInteractionController:(NSURL *)myURL withUTI:(NSString*)uti withName:(NSString*)name inView:(UIView*)view withController:(UIViewController*)controller;

+ (void) setDefaultAudioSession;
+ (void) setRecordingAudioSession;
+ (void) setMusicAudioSession;
+ (void) setProcessingAudioSession;
+ (void) requestRecordPermission;

+ (id) registerKeyboardHidingOnSheetPresentationFor:(UIViewController*)controller;

+ (void) updateStatusbarForViewController:(UIViewController*)viewcontroller style:(UIStatusBarStyle)theStyle;
+ (void) setBlackFontStatusbarForViewController:(UIViewController*)viewcontroller;
+ (void) setWhiteFontStatusbarForViewController:(UIViewController*)viewcontroller;

+ (NSString *)uniqueFilenameForFilename: (NSString *)theFilename inDirectory: (NSString *)directory;
+ (NSString *)sanitizeFileNameString:(NSString *)fileName;
+ (NSURL *)uniqueNewFileURLForFileLike:(NSString *)fileNameHint;

- (NSString *)ownIPAddress:(BOOL)preferIPv4;
- (NSDictionary *)ownIPAddresses;

+ (BOOL)validateString:(NSString *)string withPattern:(NSString *)pattern;

+ (AppDelegate*)instance;
+ (void) renewRSAKeyPairWithSize: (NSUInteger) size;

+ (BOOL)unzipFileAtURL:(NSURL*)zipFileURL toDirectory:(NSURL*)theDirectoryURL;


@end
