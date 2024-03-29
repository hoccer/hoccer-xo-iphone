////  AppDelegate.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AppDelegate.h"

#import "ConversationViewController.h"
#import "Contact.h"
#import "Attachment.h"
#import "AttachmentMigration.h"
#import "HXOMessage.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "HXOUserDefaults.h"
#import "Environment.h"
#import "UserProfile.h"
#import "UIAlertView+BlockExtensions.h"
#import "ZipArchive.h"
//#import "TestFlight.h"
#import "HXOUI.h"
#import "ChatViewController.h"
#import "ModalTaskHUD.h"
#import "GesturesInterpreter.h"
#import "HXOEnvironment.h"
#import "HXOAudioPlayer.h"
#import "HXOLocalization.h"
#import "MediaAttachmentListViewController.h"
#import "NSString+Regexp.h"
#import "PasscodeViewController.h"
#import "WebViewController.h"

#import "Contact.h"
#import "Group.h"

#if HOCCER_UNIHELD
#import "tab_benefits.h"
#endif

#import "Delivery.h" //DEBUG

#import "OpenSSLCrypto.h"
#import "Crypto.h"
#import "CCRSA.h"

#ifdef WITH_WEBSERVER
#import "HTTPServerController.h"
#endif

// #import <HockeySDK/HockeySDK.h>

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>

#import <CoreData/NSMappingModel.h>

//#import <AVFoundation/AVFoundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

#import <sys/utsname.h>

#define CONNECTION_TRACE            NO
#define MIGRATION_DEBUG             NO
#define AUDIOSESSION_DEBUG          NO
#define TRACE_DATABASE_SAVE         NO
#define TRACE_PROFILE_UPDATES       NO
#define TRACE_DELETES               NO
#define TRACE_INSPECTION            NO
#define TRACE_PENDING_CHANGES       NO
#define TRACE_BACKGROUND_PROCESSING NO
#define TRACE_NEARBY_ACTIVATION     NO
#define TRACE_LOCKING               NO
#define TRACE_DELIVERY_SAVES        NO
#define TRACE_CONTACT_SAVES         NO
#define TRACE_FILE_SEARCH           NO
#define TRACE_DOCDIR_CHANGES        NO
#define TRACE_IMAGE_CACHING         NO
#define TRACE_NOTIFICATIONS         NO
#define TRACE_MUGSHOTS              NO
#define TRACE_BACKGROUND_FINALIZER  NO
#define TRACE_TRAFFIC_MONITOR       NO
#define DEBUG_ROTATION              NO

NSString * const kHXOTransferCredentialsURLImportScheme = @"hcrimport";
NSString * const kHXOTransferCredentialsURLCredentialsHost = @"credentials";
NSString * const kHXOTransferCredentialsURLArchiveHost = @"archive";
NSString * const kHXOTransferCredentialsURLExportScheme = @"hcrexport";
NSString * const kHXOTransferArchiveUTI = @"com.hoccer.ios.archive.v1";
NSString * const kHXODefaultArchiveName = @"default.hciarch";

NSString * const kHXOReceivedNewHXOMessage = @"receivedNewHXOMessage";

NSString * const kFileChangedNotification = @"fileChangedNotification";

static NSInteger validationErrorCount = 0;

typedef void (^ImageHandler)(UIImage* image);

@interface AppDelegate ()
{
    NSMutableArray * _inspectedObjects;
    NSMutableArray * _inspectors;
    NSMutableDictionary *_idLocks;
    NSObject * _inspectionLock;
    NSMutableDictionary * _backgroundContexts;

    // File monitoring Dispatch queue
    dispatch_queue_t _dirMonitorDispatchQueue;

    // A source of potential notifications
    dispatch_source_t _dirMonitorDispatchSource;
    id<NSObject> _fileChangeObserver;
    
    unsigned long _documentDirectoryHandlingScheduledId;
    unsigned long _cancelDirectoryHandlingScheduledId;
    unsigned long _documentMonitoringDisableCounter;
    
    NSDictionary *_fileEntities;
    
    NSMutableDictionary * _previewImageCache;
    
    NSURL * _applicationDirectory;
    NSURL * _applicationDocumentDirectory;
    NSURL * _applicationTemporaryDocumentDirectory;
    NSURL * _applicationLibraryDirectory;

    unsigned long _backgroundLaunch;
    unsigned long _backgroundLaunchReady;
    unsigned long _backgroundNotification;
    unsigned long _backgroundNotificationReady;
    
    NSDictionary * _pushNotificationInfo;
    void (^_backgroundFetchHandler)(UIBackgroundFetchResult result);
    id<NSObject> _messageReceivedObserver;
    
    dispatch_queue_t _sessionQueue;
    AVCaptureSession * _captureSession;
    AVCaptureVideoDataOutput *  _videoOutput;
    AVCaptureStillImageOutput *_stillImageOutput;
    ImageHandler _captureHandler;
    unsigned long _captureCounter;
    
    unsigned long _backgroundTaskCount;
    ContinueBlock _backgroundFinalizer;
    unsigned long _backendRequestsOpen;
    NSDate *      _backendLastTrafficTime;
    BOOL          _backgroundFinalizerTriggered;

}

@property (nonatomic, strong) ModalTaskHUD * hud;
@property (nonatomic, strong) UIViewController * interactionViewController;
@property (nonatomic, strong) UIView * interactionView;
@property BOOL interactionSending;
@property BOOL interactionRemoveFileFlag;
@property (nonatomic, readonly) BOOL isPasscodeRequired;
@property (nonatomic) BOOL isLoggedOn; // will be set to true when no passcode required or passcode entered

@end

@implementation AppDelegate

@synthesize mainObjectContext = _mainObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize environmentMode = _environmentMode;

@dynamic processingBackgroundNotification;
@dynamic processingBackgroundLaunch;
@dynamic runningInBackground;
@dynamic pushNotificationInfo;


#ifdef WITH_WEBSERVER
@synthesize httpServer = _httpServer;
#endif

@synthesize rpcObjectModel = _rpcObjectModel;
@synthesize userAgent;


-(BOOL) processingBackgroundNotification {
    return _backgroundNotificationReady < _backgroundNotification;
}

-(BOOL) processingBackgroundLaunch {
    return _backgroundLaunchReady < _backgroundLaunch;
}

-(BOOL) runningInBackground {
    __block UIApplicationState state;
    if ([NSThread isMainThread]) {
        state = [UIApplication sharedApplication].applicationState;
    } else {
        dispatch_sync(dispatch_get_main_queue(),^{
            state = [UIApplication sharedApplication].applicationState;
        });
    }
    BOOL result =  state == UIApplicationStateBackground;
    if (TRACE_BACKGROUND_FINALIZER) NSLog(@"runningInBackground %d, applicationState = %ld",result, (long)state);
    return result;
}

-(NSDictionary*)pushNotificationInfo {
    return _pushNotificationInfo;
}

-(NSMutableDictionary*)previewImageCache {
    if (_previewImageCache == nil) {
        _previewImageCache = [NSMutableDictionary new];
    }
    return _previewImageCache;
}

-(void)cachePreviewImage:(UIImage*)image withName:(NSString*)name {
    if (image != nil) {
        if (TRACE_IMAGE_CACHING) NSLog(@"caching image for %@", name);
        self.previewImageCache[name] = image;
    } else {
        if ([[self previewImageCache] objectForKey:name] != nil) {
            if (TRACE_IMAGE_CACHING) NSLog(@"purging image for %@", name);
            [[self previewImageCache] removeObjectForKey:name];
        }
    }
}

-(UIImage*)getCachedPreviewImagWithName:(NSString*)name {
    return [[self previewImageCache] objectForKey:name];
}


// a string that changes when the app version, the device, the OS-Version or system language changes
// used to invalidate caches that may depend on these values
+(NSString*)appEntityId {
    static NSString * appEntityString = nil;
    if (appEntityString == nil) {
#ifdef DEBUG
        NSString * clientBuildVariant = @"debug";
#else
        NSString * clientBuildVariant = @"release";
#endif
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *machineName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        NSArray * initParams = @[[[NSLocale preferredLanguages] objectAtIndex:0],
                                 machineName,
                                 [UIDevice currentDevice].systemName,
                                 [UIDevice currentDevice].systemVersion,
                                 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                                 clientBuildVariant, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                                 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
        appEntityString = [initParams componentsJoinedByString:@"-"];
    }
    return appEntityString;
}

// see http://stackoverflow.com/questions/3181821/notification-of-changes-to-the-iphones-documents-directory

-(void) setupDocumentDirectoryMonitoring {
    
    //[self cancelDocumentDirectoryMonitoring];
    NSLog(@"setupDocumentDirectoryMonitoring");
    
    // Get the path to the home directory
    NSString * homeDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    
    // Create a new file descriptor - we need to convert the NSString to a char * i.e. C style string
    int filedes = open([homeDirectory cStringUsingEncoding:NSASCIIStringEncoding], O_EVTONLY);
    
    // Create a dispatch queue - when a file changes the event will be sent to this queue
    _dirMonitorDispatchQueue = dispatch_queue_create("FileMonitorQueue", 0);
    
    // Create a GCD source. This will monitor the file descriptor to see if a write command is detected
    // The following options are available
    
    /*!
     * @typedef dispatch_source_vnode_flags_t
     * Type of dispatch_source_vnode flags
     *
     * @constant DISPATCH_VNODE_DELETE
     * The filesystem object was deleted from the namespace.
     *
     * @constant DISPATCH_VNODE_WRITE
     * The filesystem object data changed.
     *
     * @constant DISPATCH_VNODE_EXTEND
     * The filesystem object changed in size.
     *
     * @constant DISPATCH_VNODE_ATTRIB
     * The filesystem object metadata changed.
     *
     * @constant DISPATCH_VNODE_LINK
     * The filesystem object link count changed.
     *
     * @constant DISPATCH_VNODE_RENAME
     * The filesystem object was renamed in the namespace.
     *
     * @constant DISPATCH_VNODE_REVOKE
     * The filesystem object was revoked.
     */
    
    // Write covers - adding a file, renaming a file and deleting a file...
    _dirMonitorDispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,filedes,
                                     DISPATCH_VNODE_WRITE,
                                     _dirMonitorDispatchQueue);
    
    
    // This block will be called when teh file changes
    dispatch_source_set_event_handler(_dirMonitorDispatchSource, ^(){
        // We call an NSNotification so the file can change can be detected anywhere
        [[NSNotificationCenter defaultCenter] postNotificationName:kFileChangedNotification object:nil];
    });
    
    // When we stop monitoring the file this will be called and it will close the file descriptor
    dispatch_source_set_cancel_handler(_dirMonitorDispatchSource, ^() {
        close(filedes);
    });
    
    // Start monitoring the file...
    dispatch_resume(_dirMonitorDispatchSource);
    
    // When we want to stop monitoring the file we call this
    
    // To recieve a notification about the file change we can use the NSNotificationCenter
    _fileChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kFileChangedNotification object:nil queue:nil usingBlock:^(NSNotification * notification) {
        NSLog(@"Document Directory file change detected.");
        //[AppDelegate.instance handleDocumentDirectoryChanges];
        
        double delayInSeconds = 1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        unsigned long scheduleId = ++_documentDirectoryHandlingScheduledId;
        dispatch_after(popTime, _dirMonitorDispatchQueue, ^(void) {
            [self handleDocumentDirectoryChanges:scheduleId];
        });
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:kFileChangedNotification object:nil];
}

-(void) cancelDocumentDirectoryMonitoring {
    NSLog(@"cancelDocumentDirectoryMonitoring");
    _cancelDirectoryHandlingScheduledId = _documentDirectoryHandlingScheduledId;
    if (_dirMonitorDispatchSource != nil) {
        dispatch_source_cancel(_dirMonitorDispatchSource);
    }
    _dirMonitorDispatchSource = nil;

    if (_fileChangeObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:_fileChangeObserver];
    }
    _fileChangeObserver = nil;

    if (_dirMonitorDispatchQueue != nil) {
        //dispatch_release(_dirMonitorDispatchQueue);
    }
    _dirMonitorDispatchQueue = nil;
}

-(BOOL)documentMonitoringEnabled {
    return _documentMonitoringDisableCounter == 0;
}

-(void)pauseDocumentMonitoring {
    if (_documentMonitoringDisableCounter++ == 0) {
        NSLog(@"#INFO: pauseDocumentMonitoring: disabling document monitoring");
        [self cancelDocumentDirectoryMonitoring];
    } else {
        NSLog(@"#INFO: pauseDocumentMonitoring: document monitoring already paused, count = %lu",_documentMonitoringDisableCounter);
    }
}

-(void)resumeDocumentMonitoring {
    if (_documentMonitoringDisableCounter == 0) {
        NSLog(@"#WARNING: resumeDocumentMonitoring: document monitoring already enabled");
        return;
    }
    if (--_documentMonitoringDisableCounter == 0) {
        NSLog(@"#INFO: resumeDocumentMonitoring: enabling document monitoring");
        [self setupDocumentDirectoryMonitoring];
    }
}

-(void)startedBackgroundTask {
    _backgroundTaskCount++;
    NSLog(@"#INFO: startedBackgroundTask: running = %lu",_backgroundTaskCount);
}

-(void)finishedBackgroundTask {
    if (_backgroundTaskCount == 0) {
        NSLog(@"#WARNING: finishedBackgroundTask: no backgroundtask running");
        return;
    }
    if (--_backgroundTaskCount == 0) {
        if (_backgroundFinalizer != nil && [self readyToFinalize]) {
            NSLog(@"#INFO: finishedBackgroundTask: last task finished and ready to finalize, triggering");
            [self triggerFinalizer:YES];
        }
    }
    NSLog(@"#INFO: finishedBackgroundTask: running = %lu",_backgroundTaskCount);
}

-(void)setBackgroundFinalizer:(ContinueBlock)finalizer {
    if (_backgroundFinalizer != nil) {
        NSLog(@"#WARNING: setBackgroundFinalizer: finalizer already set");
    }
    _backgroundFinalizer = finalizer;
    if ([self readyToFinalize]) {
        NSLog(@"#INFO: setBackgroundFinalizer: no backgroundtask running, finalizing");
        [self triggerFinalizer:YES];
        return;
    }
}

-(void)backendTrafficWithRequestsOpen:(unsigned long)openRequests {
    _backendRequestsOpen = openRequests;
    _backendLastTrafficTime = [NSDate new];
    if (TRACE_TRAFFIC_MONITOR) NSLog(@"#INFO: backendTrafficWithRequestsOpen %lu", openRequests);
    if (_backgroundFinalizer != nil && _backgroundTaskCount == 0 && _backendRequestsOpen == 0) {
        if (TRACE_BACKGROUND_FINALIZER) NSLog(@"#INFO: backendTrafficWithRequestsOpen no backgroundTasks, no open Requests, triggering finalizer");
        [self triggerFinalizer:YES];
    }
}

const double MIN_TRAFFIC_GAP = 1.0;

-(BOOL)readyToFinalize {
    double lastTrafficAgo = -[_backendLastTrafficTime timeIntervalSinceNow];
    if (TRACE_TRAFFIC_MONITOR) NSLog(@"readyToFinalize: _backgroundTaskCount %lu, _backendRequestsOpen %lu, _backendLastTrafficTime %f secs. ago",
          _backgroundTaskCount, _backendRequestsOpen, lastTrafficAgo);
    
    if (_backgroundTaskCount == 0 && _backendRequestsOpen == 0 &&
        (_backendLastTrafficTime == nil || lastTrafficAgo > MIN_TRAFFIC_GAP)) {
        return YES;
    }
    return NO;
}

-(void)triggerFinalizer:(BOOL)externally {
    if (_backgroundFinalizerTriggered && externally) {
        NSLog(@"#WARNING: _backgroundFinalizer already triggered");
        return;
    }
    _backgroundFinalizerTriggered = YES;
    if ([self readyToFinalize]) {
        if (_backgroundFinalizer != nil) {
            NSLog(@"#INFO: triggerFinalizer no backgroundTasks, no open Requests, no traffic, finalizing");
            _backgroundFinalizer();
            _backgroundFinalizer = nil;
        } else {
            NSLog(@"#INFO: triggerFinalizer: ending, finalizer was canceled (ready)");
        }
        _backgroundFinalizerTriggered = NO;
    } else {
        if (_backgroundFinalizer != nil) {
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, MIN_TRAFFIC_GAP * 1.2 * NSEC_PER_SEC);
            NSLog(@"#INFO: triggerFinalizer: scheduling check in %f seconds", MIN_TRAFFIC_GAP * 1.2);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                [self triggerFinalizer:NO];
            });
        } else {
            _backgroundFinalizerTriggered = NO;
            NSLog(@"#INFO: triggerFinalizer: ending, finalizer was canceled (not ready)");
        }
    }
}

-(void)cancelFinalizer {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        NSLog(@"cancelFinalizer: ending background task");
        [[UIApplication sharedApplication] endBackgroundTask: _backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
    if (_backgroundFinalizer != nil) {
        NSLog(@"cancelFinalizer: removing background finalizer");
        _backgroundFinalizer = nil;
    }
}


+ (NSDate*)getModificationDateForPath:(NSString*)myFilePath {
    NSError * error = nil;
    NSDictionary * attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:myFilePath error:&error];
    if (error != nil) {
        NSLog(@"Error getting modification date for path %@, error=%@", myFilePath, error);
        return nil;
    }
    return [attributes fileModificationDate];
}

+ (NSDate*)getCreationDateForPath:(NSString*)myFilePath {
    NSError * error = nil;
    NSDictionary * attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:myFilePath error:&error];
    if (error != nil) {
        NSLog(@"Error getting creation date for path %@, error=%@", myFilePath, error);
        return nil;
    }
    return [attributes fileCreationDate];
}

+ (BOOL)setPosixPermissions:(short)flags forPath:(NSString*)myFilePath {
    NSError * error = nil;
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @(flags)} ofItemAtPath:myFilePath error:&error];
    if (error != nil) {
        NSLog(@"Error setting posix permissions %o for path %@, error=%@", flags, myFilePath, error);
        return NO;
    }
    return YES;
}

+ (short)getPosixPermissionsForPath:(NSString*)myFilePath {
    NSError * error = nil;
    NSDictionary * attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:myFilePath error:&error];
    if (error != nil) {
        NSLog(@"Error getting posix permission for path %@, error=%@", myFilePath, error);
        return -1;
    }
    return [attributes filePosixPermissions];
}

+ (BOOL)setPosixPermissionsReadOnlyForPath:(NSString*)myFilePath {
    return [self setPosixPermissions:[@(0444) shortValue] forPath:myFilePath];
}

+ (BOOL)setPosixPermissionsReadWriteForPath:(NSString*)myFilePath {
    return [self setPosixPermissions:[@(0644) shortValue] forPath:myFilePath];
}


+(BOOL)isUserReadOnlyFile:(NSString*)myFilePath {
    short permissions = [self getPosixPermissionsForPath:myFilePath];
    if (permissions != -1) {
        return (permissions & 0200) == 0;
    }
    return NO;
}

+(BOOL)isUserReadWriteFile:(NSString*)myFilePath {
    short permissions = [self getPosixPermissionsForPath:myFilePath];
    if (permissions != -1) {
        return (permissions & 0600) == 0600;
    }
    return NO;
}

+ (BOOL)isBusyFileAtURL:(NSURL*)myFile {
    return [self isBusyFile:[myFile path]];
}

+ (BOOL)isBusyFile:(NSString*)myFilePath {
    /*
    if (![[NSFileManager defaultManager] fileExistsAtPath:myFilePath]) {
        return NO;
    }
     */
    int result;
    result = open([myFilePath UTF8String], O_RDONLY | O_NONBLOCK | O_EXLOCK);
    if (result != -1) {
        //The file is not busy
        close(result);
        return NO;
    }
    if (errno == ENOENT) {
        return NO; // file does not exist
    }
    return YES;
}

+(NSURL*)metaDataURL:(NSURL*)fileUrl {
    if ([fileUrl isFileURL]) {
        NSString * path = [fileUrl path];
        NSString * metaPath = [self metaDataPath:path];
        return [NSURL fileURLWithPath:metaPath];
    }
    return nil;
}

+(NSString*)metaDataPath:(NSString*)filePath {
    NSString * fileName = filePath.lastPathComponent;
    NSString * metaFileName = [NSString stringWithFormat:@"._%@",fileName];
    NSString * path = [filePath stringByDeletingLastPathComponent];
    NSString * result = [path stringByAppendingPathComponent:metaFileName];
    return result;
}

-(BOOL)considerFile:(NSString*)file withEntity:(NSString*)entity inDirectoryPath:(NSString*)directoryPath {
    if ([file startsWith:@"."]) {
        return NO;
    }
    if ([file isEqualToString:@"credentials.json"]) {
        return NO;
    }
    if ([entity endsWith:@"-0"]) {
        return NO;
    }
    /*
    NSString * fullPath = [directoryPath stringByAppendingPathComponent: file];
    if ([AppDelegate isBusyFile:fullPath]) {
        NSLog(@"File is busy:%@", file);
        return NO;
    }
     */
    return YES;
}

-(BOOL)emptyFile:(NSString*)file withEntity:(NSString*)entity {
    if ([entity endsWith:@"-0"]) {
        return YES;
    }
    return NO;
}

-(void)handleDocumentDirectoryChanges:(unsigned long)scheduleId {
    NSLog(@"handleDocumentDirectoryChanges %ld",scheduleId);
    if (scheduleId <= _cancelDirectoryHandlingScheduledId) {
        NSLog(@"handleDocumentDirectoryChanges canceled up to %ld",_cancelDirectoryHandlingScheduledId);
        return;
    }
    if (_documentDirectoryHandlingScheduledId > scheduleId) {
        NSLog(@"handleDocumentDirectoryChanges skipping %ld because more is already scheduled",scheduleId);
        return;
    }
    NSDictionary * oldEntities = _fileEntities;
    
    NSURL * documentDirectory = [self applicationDocumentsDirectory];
    NSString * documentDirectoryPath = [documentDirectory path];
    NSArray * files = [AppDelegate fileNamesInDirectoryAtURL:documentDirectory ignorePaths:@[] ignoreSuffixes:@[@"hciarch"]];
    NSMutableDictionary * newEntities = [AppDelegate entityIdsOfFiles:files inDirectory:documentDirectory];
    
    NSMutableArray * changedFiles = [NSMutableArray new];
    NSMutableArray * newFiles = [NSMutableArray new];
    NSMutableArray * deletedFiles = [NSMutableArray new];
    
    // find deleted files first, we may filter out somw newEntities later
    for (NSString * file in oldEntities) {
        NSString * newEntity = newEntities[file];
        if (newEntity == nil) {
            if ([self considerFile:file withEntity:oldEntities[file] inDirectoryPath:documentDirectoryPath]) {
                if (TRACE_DOCDIR_CHANGES) NSLog(@"deletedFile: %@ (%@)", file, oldEntities[file]);
                [deletedFiles addObject:file];
            } else {
                if (TRACE_DOCDIR_CHANGES) NSLog(@"Not considering deletedFile: %@ (%@)", file, oldEntities[file]);
            }
        }
    }
    
    // find new and changed files
    for (NSString * file in newEntities) {
        NSString * oldEntity = oldEntities[file];
        if (oldEntity == nil) {
            BOOL retryScheduled = _documentDirectoryHandlingScheduledId > scheduleId;
            BOOL cancelled = scheduleId <= _cancelDirectoryHandlingScheduledId;
            if (cancelled) {
                NSLog(@"handleDocumentDirectoryChanges(2) id %ld canceled up to %ld",scheduleId,_cancelDirectoryHandlingScheduledId);
                return;
            }
            if (!retryScheduled && [self emptyFile:file withEntity:newEntities[file]]) {
                
                double delayInSeconds = 5;
                if (TRACE_DOCDIR_CHANGES,YES) NSLog(@"newFile: %@ is empty, retry changes in %f secs", file, delayInSeconds);
                NSString * fullPath = [documentDirectoryPath stringByAppendingPathComponent: file];

                if (TRACE_DOCDIR_CHANGES,YES) NSLog(@"newFile: %@ created: %@ changed: %@", file, [AppDelegate getCreationDateForPath:fullPath], [AppDelegate getModificationDateForPath:fullPath]);
                
                
                // this happens when files are added using itunes
                
                unsigned long retryScheduleId = ++_documentDirectoryHandlingScheduledId;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                NSLog(@"handleDocumentDirectoryChanges: scheduling retry id %ld in %f seconds", retryScheduleId, delayInSeconds);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                    NSLog(@"handleDocumentDirectoryChanges: retrying id %ld", retryScheduleId);
                    [self handleDocumentDirectoryChanges:retryScheduleId];
                });
            }
            if ([self considerFile:file withEntity:newEntities[file] inDirectoryPath:documentDirectoryPath]) {
                if (TRACE_DOCDIR_CHANGES) NSLog(@"newFile: %@ (%@)", file, newEntities[file]);
                [newFiles addObject:file];
            } else {
                if (TRACE_DOCDIR_CHANGES) NSLog(@"Not considering newFile: %@ (%@)", file, newEntities[file]);
            }
        } else {
            NSString * newEntity = newEntities[file];
            if (newEntity != nil) {
                if (![newEntity isEqualToString:oldEntity]) {
                    if ([self considerFile:file withEntity:newEntities[file]inDirectoryPath:documentDirectoryPath]) {
                        if (TRACE_DOCDIR_CHANGES) NSLog(@"changedFile: %@ (%@ -> %@)", file, oldEntity, newEntity);
                        [changedFiles addObject:file];
                    } else {
                        if (TRACE_DOCDIR_CHANGES) NSLog(@"Not considering changedFiles: %@ (%@)", file, newEntities[file]);
                    }
                }
            }
        }
    }
    if (changedFiles.count > 0 || newFiles.count > 0 || deletedFiles.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL cancelled = scheduleId <= _cancelDirectoryHandlingScheduledId;
            if (cancelled) {
                NSLog(@"handleDocumentDirectoryChanges(3) id %ld canceled up to %ld",scheduleId,_cancelDirectoryHandlingScheduledId);
                return;
            }
            [AttachmentMigration adoptOrphanedFiles:newFiles changedFiles:changedFiles deletedFiles:deletedFiles withRemovingAttachmentsNotInFiles:files inDirectory:documentDirectory];
        });
    }
    
    _fileEntities = newEntities;
    [self saveDictionary:_fileEntities toFile:@"fileEntities"];
}

-(void)printInspection {
    @synchronized(_inspectionLock) {
        int i = 0;
        for (id obj in _inspectedObjects) {
            NSLog(@"%d)inspected id %@ name %@ by %@", i,[obj clientId], [obj nickName], [_inspectors[i] class]);
            ++i;
        }
        NSLog(@"\n");
    }
}

-(void)beginInspecting:(id)inspectedObject withInspector:(id)inspector {
    @synchronized(_inspectionLock) {
        if (TRACE_INSPECTION) NSLog(@"--> begin inspecting type %@ id %@ name %@ withInspector %@",[inspectedObject class], [inspectedObject clientId], [inspectedObject nickName], [inspector class]);
        if (_inspectedObjects == nil) {
            _inspectedObjects = [NSMutableArray new];
            _inspectors = [NSMutableArray new];
        }
        if (inspectedObject != nil) {
            [_inspectedObjects insertObject:inspectedObject atIndex:0];
            [_inspectors insertObject:inspector atIndex:0];
        }
        if (TRACE_INSPECTION) [self printInspection];
    }
}

-(void)endInspecting:(id)inspectedObject withInspector:(id)inspector {
    @synchronized(_inspectionLock) {
        if (TRACE_INSPECTION) NSLog(@"<-- end inspecting type %@ id %@ name %@ withInspector %@",[inspectedObject class], [inspectedObject clientId], [inspectedObject nickName], [inspector class]);
        if (_inspectedObjects == nil) {
            _inspectedObjects = [NSMutableArray new];
            _inspectors = [NSMutableArray new];
        }
        for (int i = 0; i < _inspectedObjects.count;++i) {
            if (_inspectedObjects[i] == inspectedObject && _inspectors[i] == inspector) {
                [_inspectedObjects removeObjectAtIndex:i];
                [_inspectors removeObjectAtIndex:i];
                break;
            }
        }
        if (TRACE_INSPECTION) [self printInspection];
    }
}

-(BOOL)isInspecting:(id)inspectedObject withInspector:(id)inspector {
    @synchronized(_inspectionLock) {
        if (inspectedObject == nil || inspector == nil) {
            return false;
        }
        for (int i = 0; i < _inspectedObjects.count;++i) {
            if (sameObjects(_inspectedObjects[i],inspectedObject) && _inspectors[i] == inspector) {
                return YES;
            }
        }
        return NO;
    }
}

BOOL sameObjects(id obj1, id obj2) {
    if ([obj1 isKindOfClass:[NSManagedObject class]] && [obj2 isKindOfClass:[NSManagedObject class]]) {
        NSManagedObject * mo1 = (NSManagedObject*)obj1;
        NSManagedObject * mo2 = (NSManagedObject*)obj2;
        return [mo1.objectID isEqual:mo2.objectID];
    }
    return [obj1 isEqual:obj2];
}

-(BOOL)isInspecting:(id)inspectedObject {
    @synchronized(_inspectionLock) {
        if (_inspectedObjects == nil) {
            return false;
        }
        for (int i = 0; i < _inspectedObjects.count;++i) {
            //NSLog(@"isInspecting: compare %@ with %@", _inspectedObjects[i], inspectedObject);
            if (sameObjects(_inspectedObjects[i],inspectedObject)) {
                return YES;
            }
        }
        return NO;
    }
}

-(id)inspectorOf:(id)inspectedObject {
    @synchronized(_inspectionLock) {
        if (_inspectedObjects == nil) {
            return false;
        }
        if (inspectedObject != nil) {
            for (int i = 0; i < _inspectedObjects.count;++i) {
                if (sameObjects(_inspectedObjects[i],inspectedObject)) {
                    return _inspectors[i];
                }
            }
        }
        return nil;
    }
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self seedRand];
    _backgroundTask = UIBackgroundTaskInvalid;
    //[[UserProfile sharedProfile] deleteCredentials];

#ifdef DEBUG_RESPONDER
    //[UIResponder hijack];
    NSLog(@"Responder Chain %@", NBResponderChain());
#endif
    return YES;
}


- (void)registerForRemoteNotifications {
    UIApplication * application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [application registerUserNotificationSettings:notificationSettings];
        [application registerForRemoteNotifications];
    } else {
        [application registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
}

-(void)presentUserNotificationWithTitle:(NSString*)theTitle withText:(NSString*)theText withInfo:(NSDictionary*)userInfo {
    
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    
    if (localNotif == nil) {
        return;
    }
    
    localNotif.alertBody = theText;
    if ([localNotif respondsToSelector:@selector(alertTitle)]) {
        localNotif.alertTitle = theTitle;
    }
    localNotif.alertAction = NSLocalizedString(@"open", nil);
    localNotif.soundName = UILocalNotificationDefaultSoundName;
    
    NSUInteger unreadMessages = [self unreadMessageCount];
    localNotif.applicationIconBadgeNumber = unreadMessages;
    
    localNotif.userInfo = userInfo;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
}
/*
-(void)presentUserNotificationWithInfo:(NSDictionary*)userInfo {
    
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    
    if (localNotif == nil) {
        return;
    }

    NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
    
    NSString * alertMsg = apsInfo[@"alert"];

    NSNumber * badge = apsInfo[@"badge"];
    NSString * sound = apsInfo[@"sound"];
    
    
    // Set your appending text.
    NSString *textToAdd = [NSString stringWithFormat:@":%@", alertMsg];

    
    
    localNotif.alertBody = theText;
    if ([localNotif respondsToSelector:@selector(alertTitle)]) {
        localNotif.alertTitle = theTitle;
    }
    localNotif.alertAction = NSLocalizedString(@"open", nil);
    localNotif.soundName = UILocalNotificationDefaultSoundName;
    
    //localNotif.applicationIconBadgeNumber = 1;
    
    localNotif.userInfo = userInfo;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
}
*/

+ (id) registerKeyboardHidingOnSheetPresentationFor:(UIViewController*)controller {
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"hxoSheetViewShown"
                                                                    object:nil
                                                                     queue:[NSOperationQueue mainQueue]
                                                                usingBlock:^(NSNotification *note) {
                                                                        NSLog(@"hxoSheetViewShown - hiding keyboard via endEditing");
                                                                        [controller.view endEditing:NO];
                                                                }];
    return observer;
}

- (BOOL) saveDictionary:(NSDictionary*)dict toFile:(NSString*)fileName {
    NSURL * fileURL = [self cacheFileURL:fileName];
    return [dict writeToURL:fileURL atomically:YES];
}

- (NSMutableDictionary*) loadDictionary:(NSString*)fileName {
    NSURL * fileURL = [self cacheFileURL:fileName];
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithContentsOfURL:fileURL];
    return result;
}

-(void)cleanupTmpDirectory {
    NSString * tmpDir = NSTemporaryDirectory();
    NSError * error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]) {
        NSLog(@"Removing tmp directory at path %@", tmpDir);
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:&error];
        if (error != nil) {
            NSLog(@"Error removing tmp dir at %@, error=%@", tmpDir, error);
        } else {
            NSLog(@"Removed tmp directory at URL %@", tmpDir);
        }
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&error];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    gAppDelegate = self;

    [self cleanupTmpDirectory];
    NSLog(@"Running with environment %@", [Environment sharedEnvironment].currentEnvironment);

    //CCRSA * rsa = [CCRSA sharedInstance];
    //[rsa findKeyPairs];

#ifdef DEBUG
    [self testFSSize];
#endif
    _documentMonitoringDisableCounter = 1; // account for document monitoring is not running at launch

    _idLocks = [NSMutableDictionary new];
    _backgroundContexts = [NSMutableDictionary new];
    _inspectionLock = [NSObject new];
    //_fileEntities = [self loadDictionary:@"fileEntities"];
    if (_fileEntities == nil) {
        _fileEntities = [NSDictionary new];
    } else {
        NSLog(@"initialized _fileEntities with %ld values", (unsigned long)_fileEntities.count);
    }
//#ifdef HOCCER_DEV
//    [[HXOUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:NO] forKey: kHXOWorldwideHidden];
//#else
    [[HXOUserDefaults standardUserDefaults] setObject: [NSNumber numberWithBool:YES] forKey: kHXOWorldwideHidden];
//#endif
    
#ifdef DEBUG
//#define DEFINE_OTHER_SERVERS
#endif
#ifdef DEFINE_OTHER_SERVERS
    //[[HXOUserDefaults standardUserDefaults] setValue: @"ws://10.1.9.166:8080/" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"http://10.1.9.166:8081/" forKey: kHXOForceFilecacheURL];
    
    //[[HXOUserDefaults standardUserDefaults] setValue: @"wss://talkserver.talk.hoccer.de:8443/" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"https://filecache.talk.hoccer.de:8444/" forKey: kHXOForceFilecacheURL];

    [[HXOUserDefaults standardUserDefaults] setValue: @"ws://192.168.2.25:8080/" forKey: kHXODebugServerURL];
    [[HXOUserDefaults standardUserDefaults] setValue: @"http://192.168.2.25:8081/" forKey: kHXOForceFilecacheURL];
    
    //[[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXOForceFilecacheURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
#else
    [[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXODebugServerURL];
    [[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXOForceFilecacheURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
#endif
    
    if ([[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOReportCrashes] boolValue]) {
        //NSLog(@"TestFlight launching with token %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"HXOTestFlightToken"]);
        //[TestFlight takeOff: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"HXOTestFlightToken"]];
    } else {
        //NSLog(@"TestFlight crash reporting is disabled");
    }
    
    if (!UserProfile.sharedProfile.hasKeyPair) {
        dispatch_async(dispatch_get_main_queue(), ^{ // delay until window is realized
            [AppDelegate renewRSAKeyPairWithSize: kHXODefaultKeySize];
        });
    }
    
    application.applicationSupportsShakeToEdit = NO;
    
    if (![self applicationTemporaryDocumentsDirectory]) {
        return NO;
    }

    if ([self persistentStoreCoordinator] == nil) {
        return NO;
    }
    [self registerForRemoteNotifications];
    
    [self checkForCrash];
    self.chatBackend = [[HXOBackend alloc] initWithDelegate: self];

    [UIStoryboard storyboardWithName: @"Main" bundle: [NSBundle mainBundle]];

    [[HXOUI theme] setupTheming];

    BOOL showEula = [self needsEulaAcceptance];
    BOOL isFirstRun = ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]] || showEula;

    NSLog(@"isFirstRun:%d, isRegistered:%d, eula version: %@ accepted eula: %@", isFirstRun, [UserProfile sharedProfile].isRegistered, [self eulaVersion], [self acceptedEulaVersion]);
    
    BOOL passcodeRequired = self.isPasscodeRequired;
    
    if (isFirstRun || ![UserProfile sharedProfile].isRegistered) {
        [self.chatBackend disable];
        dispatch_async(dispatch_get_main_queue(), ^{  // delay until window is realized
            [self.window.rootViewController performSegueWithIdentifier: @"showSetup" sender: self];
        });
    } else {
        if (!passcodeRequired) {
            [self tryMakeMugShot];
            [self setupDone: NO];
        }
    }
    
    NSString * buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
    NSString * lastRunBuildNumber = [[HXOUserDefaults standardUserDefaults] valueForKey:[[Environment sharedEnvironment] suffixedString:kHXOlatestBuildRun]];
    if ([buildNumber isEqualToString: lastRunBuildNumber]) {
        [[HXOUserDefaults standardUserDefaults] setBool: NO forKey: kHXOrunningNewBuild];
        self.runningNewBuild = NO;
    } else {
        [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: kHXOrunningNewBuild];
        self.runningNewBuild = YES;
        NSLog(@"Running new build %@ for the first time",buildNumber);
    }
    /*
    if ([UserProfile sharedProfile].isRegistered && (![UserProfile sharedProfile].foundCredentialsBackup || self.runningNewBuild)) {
        [[UserProfile sharedProfile] backupCredentials];
    }
     */
        
    [[HXOUserDefaults standardUserDefaults] setValue:buildNumber forKey: [[Environment sharedEnvironment] suffixedString:kHXOlatestBuildRun]];
    
    self.internetReachabilty = [GCNetworkReachability reachabilityForInternetConnection];
    [self.internetReachabilty startMonitoringNetworkReachabilityWithNotification];
    

    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] != nil) {
        // TODO: jump to conversation
        NSLog(@"Launched by remote notification.");
    }
    
    [AppDelegate setDefaultAudioSession];

    
    _messageReceivedObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kHXOReceivedNewHXOMessage
                                                                                 object:nil
                                                                                  queue:[NSOperationQueue mainQueue]
                                                                             usingBlock:^(NSNotification *note) {
                                                                                 if (TRACE_NOTIFICATIONS) NSLog(@"AppDelegate: Message received observed");
                                                                                 NSDictionary * info = [note userInfo];
                                                                                 HXOMessage * message = (HXOMessage *)info[@"message"];
                                                                                 
                                                                                 if (message != nil &&
                                                                                     self.runningInBackground)
                                                                                 {
                                                                                     Delivery * delivery = message.deliveries.anyObject;
                                                                                     Contact * chat = message.contact;
                                                                                     Contact * sender = delivery.sender;
                                                                                     
                                                                                     if (!chat.hasNotificationsEnabled) {
                                                                                         if (TRACE_NOTIFICATIONS) NSLog(@"AppDelegate: Message received, but notifications disabled for chat %@",chat.nickName);
                                                                                         return;
                                                                                     }

                                                                                     
                                                                                     NSString * messageText = nil;
                                                                                     NSString * title = nil;
                                                                                     NSDictionary * messageInfo = nil;
                                                                                     
                                                                                     if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOAnonymousNotifications]) {
                                                                                         messageText = NSLocalizedString(@"message_received_while_stopping", nil);
                                                                                         title = HXOAppName();
                                                                                     } else {
                                                                                         if ([chat.clientId isEqualToString:sender.clientId]) {
                                                                                             title = sender.nickNameOrAlias;
                                                                                         } else {
                                                                                             title = [NSString stringWithFormat:@"%@->%@",sender.nickNameOrAlias,chat.nickNameOrAlias];
                                                                                         }
                                                                                         messageText = message.body;
                                                                                         if (message.attachment != nil) {
                                                                                             NSString * typeStringName = [NSString stringWithFormat:@"attachment_type_%@",message.attachment.mediaType];
                                                                                             NSString * typeString = NSLocalizedString(typeStringName, nil);
                                                                                             messageText = [NSString stringWithFormat:@"[%@] %@",typeString,messageText];
                                                                                         }
                                                                                         messageText = [NSString stringWithFormat:@"%@:%@",message.contact.nickNameOrAlias,messageText];
                                                                                         
                                                                                     }
                                                                                     
                                                                                     messageInfo = @{@"type":@"userMessage",
                                                                                                     @"messageId":message.messageId,
                                                                                                     @"messageTag":message.messageTag,
                                                                                                     @"contactId":chat.clientId,
                                                                                                     @"senderId":sender.clientId};

                                                                                     if (TRACE_NOTIFICATIONS) NSLog(@"AppDelegate: presenting user notification with text = %@, info = %@",messageText,messageInfo);
                                                                                     [self presentUserNotificationWithTitle:title withText:messageText withInfo:messageInfo];
                                                                                 } else {
                                                                                     if (TRACE_NOTIFICATIONS) NSLog(@"AppDelegate: Message received, but notifications not shown, message =%@, background = %d, appState = %ld",message, self.runningInBackground, (long)[UIApplication sharedApplication].applicationState);
                                                                                    
                                                                                 }
                                                                             }];
    if (_messageReceivedObserver != nil) {
        if (TRACE_NOTIFICATIONS) NSLog(@"AppDelegate: Registered messageReceivedObserver = %@",_messageReceivedObserver);
    } else {
        NSLog(@"#ERROR: AppDelegate: Registering messageReceivedObserver failed");
    }
    
    NSString * dumpRecordsForEntity = [[HXOUserDefaults standardUserDefaults] valueForKey: @"dumpRecordsForEntity"];
    if (dumpRecordsForEntity.length > 0) {
        [self dumpAllRecordsOfEntityNamed:dumpRecordsForEntity];
    }

#ifdef PASSWORD_BASELINE
    unsigned char salt[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32};
    NSData * mySalt = [NSData dataWithBytes:&salt length:32];
    NSData * myKey = [Crypto make256BitKeyFromPassword:@"myPassword" withSalt:mySalt];
    NSLog(@"myKey=%@", [myKey hexadecimalString]);
#endif
    
    [AttachmentMigration determinePlayabilityForAllAudioAttachments];

    NSAssert([self.window.rootViewController isKindOfClass:[UITabBarController class]], @"Expecting UITabBarController");
    ((UITabBarController *)self.window.rootViewController).delegate = self;
    self.tabBarController = (UITabBarController*)self.window.rootViewController;
#if HOCCER_UNIHELD
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    UINavigationController * navi = (UINavigationController*)[storyboard instantiateViewControllerWithIdentifier:@"webViewController"];
    WebViewController * benefitTab = (WebViewController*)navi.viewControllers.firstObject;
    benefitTab.title = HXOLabelledLocalizedString(@"uniheld_benefit_title", nil);
    benefitTab.homeUrl = HXOLabelledLocalizedString(@"uniheld_benefit_url", nil);
    //benefitTab.tabBarItem.image = [UIImage imageNamed:@"placeholder-benefits.png"];
    
    benefitTab.tabBarItem.image = [[[tab_benefits alloc] init] image];


    NSMutableArray * tabs = [NSMutableArray arrayWithArray: self.tabBarController.viewControllers];
    [tabs insertObject: navi atIndex: 0];
    self.tabBarController.viewControllers = tabs;
#endif
    
    if (passcodeRequired && !isFirstRun) {
        [self performSelectorOnMainThread: @selector(requestUserAuthentication:) withObject: self waitUntilDone: NO];
    } else {
        if (!self.runningInBackground) {
            self.isLoggedOn = YES;
        }
    }

    [self setLastActiveDate];

    return YES;
}

- (void) checkForCrash {
    self.launchedAfterCrash = NO;
    NSDate * lastActiveDate = [[HXOUserDefaults standardUserDefaults] valueForKey:[[Environment sharedEnvironment] suffixedString:kHXOlastActiveDate]];
    NSDate * lastDeactivationDate = [[HXOUserDefaults standardUserDefaults] valueForKey:[[Environment sharedEnvironment] suffixedString:kHXOlastDeactivationDate]];
    if (lastActiveDate != nil) {
        if ([lastActiveDate timeIntervalSinceDate:lastDeactivationDate] > 0 || lastDeactivationDate == nil) {
            NSLog(@"INFO: App has crashed since last launch, lastActiveDate %@, lastDeactivationDate %@", lastActiveDate, lastDeactivationDate);
            self.launchedAfterCrash =YES;
        }
    }
}

- (void) setLastActiveDate {
    NSDate * now = [NSDate date];
    [[HXOUserDefaults standardUserDefaults] setValue:now forKey: [[Environment sharedEnvironment] suffixedString:kHXOlastActiveDate]];
}

- (void) setLastDeactivationDate {
    NSDate * now = [NSDate date];
    [[HXOUserDefaults standardUserDefaults] setValue:now forKey: [[Environment sharedEnvironment] suffixedString:kHXOlastDeactivationDate]];
}

- (void) setLastLogOffDate {
    NSDate * now = [NSDate date];
    [[HXOUserDefaults standardUserDefaults] setValue:now forKey: [[Environment sharedEnvironment] suffixedString:kHXOlastLogOffDate]];
}

+ (void) setDefaultAudioSession {
    [AppDelegate setAudioSessionWithCategory:AVAudioSessionCategoryAmbient];
}

+ (void) setRecordingAudioSession {
    [[HXOAudioPlayer sharedInstance] stop];
    [AppDelegate setAudioSessionWithCategory:AVAudioSessionCategoryPlayAndRecord];
    [AppDelegate requestRecordPermission];
}

+ (void) setProcessingAudioSession {
    [AppDelegate setAudioSessionWithCategory:AVAudioSessionCategoryAudioProcessing];
}


+ (void) setMusicAudioSession {
    [AppDelegate setAudioSessionWithCategory:AVAudioSessionCategoryPlayback];
}

+ (void) setAudioSessionWithCategory:(NSString *)category {
    if (AUDIOSESSION_DEBUG) NSLog(@"setAudioSessionWithCategory:%@", category);
    NSError * myError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    if (![session.category isEqualToString:category]) {
        [session setActive:NO error:&myError];
        if (myError != nil) {
            NSLog(@"ERROR: failed to deactivate prior audio session, error=%@", myError);
        }
        
        [session setCategory:category error:&myError];
        if (myError != nil) {
            NSLog(@"ERROR: failed to set audio category '%@', error=%@", category, myError);
        }
        
        [session setActive:YES error:&myError];
        if (myError != nil) {
            NSLog(@"ERROR: failed to activate audio session for category '%@', error=%@", category, myError);
        }
    }
}

+ (void) requestRecordPermission {
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    if ([session respondsToSelector:@selector(requestRecordPermission:)]) {
        [session performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            if (granted) {
                // Microphone enabled code
                if (AUDIOSESSION_DEBUG) NSLog(@"Microphone is enabled..");
            }
            else {
                // Microphone disabled code
                if (AUDIOSESSION_DEBUG) NSLog(@"Microphone is disabled..");
                
                // We're in a background thread here, so jump to main thread to do UI work.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [AppDelegate showMicrophoneAcccessDeniedAlert];
                });
            }
        }];
    }
}

+ (void) showMicrophoneAcccessDeniedAlert {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"permission_denied_title", nil)
                                                     message: HXOLocalizedString(@"permission_denied_microphone_message", nil, HXOAppName())
                                             completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alertView) { }
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

- (void) seedRand {
    unsigned seed;
    SecRandomCopyBytes(kSecRandomDefault, sizeof seed, (uint8_t*)&seed);
    srand(seed);
}

- (void) setupDone: (BOOL) performRegistration {
    NSLog(@"setupDone");
    [self.chatBackend enable];
    [self.chatBackend start: performRegistration];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    NSLog(@"applicationWillResignActive");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"applicationDidEnterBackground");
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [self.chatBackend changePresenceToNormal]; // not typing anymore ... yep, pretty sure...
    if (self.documentMonitoringEnabled) {
        [self pauseDocumentMonitoring];
    }
    [self saveDatabaseNow];
    [self setLastActiveDate];
    if (self.environmentMode != ACTIVATION_MODE_NONE) {
        [self suspendEnvironmentMode]; // for resuming nearby or worldwide mode, the Conversations- or ChatView are responsible; the must do it after login
    }
    if (self.isLoggedOn) {
        [self setLastLogOffDate];
        self.isLoggedOn = NO;
    }


    [self updateNotificationServiceExtensionNickNameTables];
    [self updateUnreadMessageCountAndStop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

    NSLog(@"applicationWillEnterForeground");
    NSLog(@"applicationWillEnterForeground: backend: %@", HXOBackend.instance.stateString);

    if (self.chatBackend.isLoggedIn) {
        NSLog(@"applicationWillEnterForeground: still connected, keeping connection open");
        [self cancelFinalizer];
        [self resumeDocumentMonitoring];
        if (self.environmentMode != ACTIVATION_MODE_NONE) {
            [self configureForMode:self.environmentMode];
        }
        self.isLoggedOn = YES;
    } else {
        if (self.isPasscodeRequired) {
            [self.chatBackend disable];
            [self requestUserAuthentication: nil];
        } else {
            [self tryMakeMugShot];
            self.isLoggedOn = YES;
            [self.chatBackend start: NO];
        }
    }

    [self setLastActiveDate];
}

-(void)tryMakeMugShot {
    
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOAccessControlPhotoEnabled]) {
        
        [self makeSnapShot:^(UIImage *image) {
            if (image) {
                AudioServicesPlaySystemSound(1108);
                //UIPasteboard.generalPasteboard.image = image;
                //[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
                
                NSURL * myFileURL = nil;
                UIImage * myImage = [Attachment qualityAdjustedImage:image];
                NSString * newFileName = @"mugshot.jpg";
                myFileURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
                
                float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
                [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myFileURL atomically:NO];
                NSURL * permanentURL = [AppDelegate moveDocumentToPermanentLocation:myFileURL];
                NSLog(@"Created and moved mugshot to %@", permanentURL);
                [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: kHXOShowMugshotDialog];
            }
        }];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"applicationDidBecomeActive");
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    NSLog(@"applicationDidReceiveMemoryWarning");
    NSLog(@"applicationDidReceiveMemoryWarning: purging image cache");
    _previewImageCache = nil;
    NSLog(@"applicationDidReceiveMemoryWarning: saving main context");
    [self saveDatabaseNow];
    //NSLog(@"applicationDidReceiveMemoryWarning: resetting main context");
    //[self.mainObjectContext reset];
    NSLog(@"applicationDidReceiveMemoryWarning: done freeing memory");
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
    [self setLastDeactivationDate];
}

#pragma mark - Nearby / Worldwide

-(void)configureForMode:(EnvironmentActivationMode)mode {
    if (TRACE_NEARBY_ACTIVATION) NSLog(@"configureForMode= %d", mode);
    [HXOEnvironment.sharedInstance setActivation:mode];
    if (mode == ACTIVATION_MODE_NONE) {
        [GesturesInterpreter.instance stop];
    } else if (mode == ACTIVATION_MODE_NEARBY) {
        [GesturesInterpreter.instance start];
    }
    _environmentMode = mode;
}

-(void)suspendEnvironmentMode {
    NSLog(@"suspendEnvironmentMode");
    [HXOEnvironment.sharedInstance deactivateLocation];
    [GesturesInterpreter.instance stop];
}

#pragma mark - Core Data stack

- (void)checkObjectsInContext:(NSManagedObjectContext*)context info:(NSString*)where {
    NSSet * registeredObjects = context.deletedObjects;
    //NSLog(@"------ checkObjectsInContext: %@", where);
    for (NSManagedObject * obj in registeredObjects) {
        if (obj.observationInfo != nil) {
            NSLog(@"#ERROR:: observers still registered on save for entity %@ %@%@%@ observation:%@", obj.entity.name, obj.isDeleted?@"deleted ":@"", obj.isUpdated?@"updated":@"", obj.isInserted?@"inserted":@"", obj.observationInfo);
        }
    }
    //NSLog(@"------ done %@", where);
}

- (void)checkObjectsInContextForDeliveries:(NSManagedObjectContext*)context info:(NSString*)where {
    NSSet * insertedObjects = context.insertedObjects;
    for (NSManagedObject * obj in insertedObjects) {
        if ([obj isKindOfClass:[Delivery class]]) {
            Delivery * delivery = (Delivery*)obj;
            NSLog(@"=== insert delivery messageId %@ receiverId %@ state %@ changed %@ in %@", delivery.message.messageId, delivery.receiver.clientId, delivery.state, delivery.timeChangedMillis, where);
        }
    }
   NSSet * registeredObjects = context.updatedObjects;
    for (NSManagedObject * obj in registeredObjects) {
        if ([obj isKindOfClass:[Delivery class]]) {
            Delivery * delivery = (Delivery*)obj;
            NSLog(@"=== updating delivery messageId %@ receiverId %@ state %@ changed %@ in %@", delivery.message.messageId, delivery.receiver.clientId, delivery.state, delivery.timeChangedMillis, where);
        }
    }
}

- (void)checkObjectsInContextForContacts:(NSManagedObjectContext*)context info:(NSString*)where {
    NSSet * insertedObjects = context.insertedObjects;
    for (NSManagedObject * obj in insertedObjects) {
        if ([obj isKindOfClass:[Contact class]]) {
            Contact * contact = (Contact*)obj;
            NSLog(@"=== inserted contact id %@ nick %@ connectionStatus %@ objId %@ in %@", contact.clientId, contact.nickName, contact.connectionStatus, contact.objectID, where);
        }
    }
    NSSet * updatedObjects = context.updatedObjects;
    for (NSManagedObject * obj in updatedObjects) {
        if ([obj isKindOfClass:[Contact class]]) {
            Contact * contact = (Contact*)obj;
            NSLog(@"=== updated contact id %@ nick %@ connectionStatus %@ objId %@ in %@", contact.clientId, contact.nickName, contact.connectionStatus, contact.objectID, where);
        }
    }
    NSSet * deletedObjects = context.deletedObjects;
    for (NSManagedObject * obj in deletedObjects) {
        if ([obj isKindOfClass:[Contact class]]) {
            Contact * contact = (Contact*)obj;
            NSLog(@"=== deleted contact objId %@ in %@", contact.objectID, where);
        }
    }
}

- (void)saveContext
{
    [self assertMainContext];
    NSDate * start;
    if (TRACE_DATABASE_SAVE) {
        NSLog(@"Saving database");
        start = [[NSDate alloc] init];
    }
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.mainObjectContext;
    if (![managedObjectContext isEqual:self.mainObjectContext]) {
        NSLog(@"ERROR: saveContext must be called on main context only");
        return;
    }
    if (managedObjectContext != nil) {
        [self checkObjectsInContext:managedObjectContext info:@"before save"];
        if (TRACE_DELIVERY_SAVES) [self checkObjectsInContextForDeliveries:managedObjectContext info:@" main context saving"];
        if (TRACE_CONTACT_SAVES) [self checkObjectsInContextForContacts:managedObjectContext info:@"main context saving"];
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            ++validationErrorCount;
            if (validationErrorCount < 3) {
                [self displayValidationError:error];
            } else {
                [self showFatalErrorAlertWithMessage:nil withTitle:nil];
            }
            // abort();
        }
        [self checkObjectsInContext:managedObjectContext info:@"after save"];
    }
    if (start && TRACE_DATABASE_SAVE) {
        double elapsed = -[start timeIntervalSinceNow];
        NSLog(@"Saving database took %f secs", elapsed);
    }
}

- (void)displayValidationError:(NSError *)anError {
    if (anError && [[anError domain] isEqualToString:@"NSCocoaErrorDomain"]) {
        NSArray *errors = nil;
        
        // multiple errors?
        if ([anError code] == NSValidationMultipleErrorsError) {
            errors = [[anError userInfo] objectForKey:NSDetailedErrorsKey];
        } else {
            errors = [NSArray arrayWithObject:anError];
        }
        
        if (errors && [errors count] > 0) {
            NSString *messages = @"Reason(s):\n";
            
            for (NSError * error in errors) {
                NSString *entityName = [[[[error userInfo] objectForKey:@"NSValidationErrorObject"] entity] name];
                NSString *attributeName = [[error userInfo] objectForKey:@"NSValidationErrorKey"];
                NSString *msg;
                switch ([error code]) {
                    case NSManagedObjectValidationError:
                        msg = @"Generic validation error.";
                        break;
                    case NSValidationMissingMandatoryPropertyError:
                        msg = [NSString stringWithFormat:@"The attribute '%@' mustn't be empty.", attributeName];
                        break;
                    case NSValidationRelationshipLacksMinimumCountError:
                        msg = [NSString stringWithFormat:@"The relationship '%@' doesn't have enough entries.", attributeName];
                        break;
                    case NSValidationRelationshipExceedsMaximumCountError:
                        msg = [NSString stringWithFormat:@"The relationship '%@' has too many entries.", attributeName];
                        break;
                    case NSValidationRelationshipDeniedDeleteError:
                        msg = [NSString stringWithFormat:@"To delete, the relationship '%@' must be empty.", attributeName];
                        break;
                    case NSValidationNumberTooLargeError:
                        msg = [NSString stringWithFormat:@"The number of the attribute '%@' is too large.", attributeName];
                        break;
                    case NSValidationNumberTooSmallError:
                        msg = [NSString stringWithFormat:@"The number of the attribute '%@' is too small.", attributeName];
                        break;
                    case NSValidationDateTooLateError:
                        msg = [NSString stringWithFormat:@"The date of the attribute '%@' is too late.", attributeName];
                        break;
                    case NSValidationDateTooSoonError:
                        msg = [NSString stringWithFormat:@"The date of the attribute '%@' is too soon.", attributeName];
                        break;
                    case NSValidationInvalidDateError:
                        msg = [NSString stringWithFormat:@"The date of the attribute '%@' is invalid.", attributeName];
                        break;
                    case NSValidationStringTooLongError:
                        msg = [NSString stringWithFormat:@"The text of the attribute '%@' is too long.", attributeName];
                        break;
                    case NSValidationStringTooShortError:
                        msg = [NSString stringWithFormat:@"The text of the attribute '%@' is too short.", attributeName];
                        break;
                    case NSValidationStringPatternMatchingError:
                        msg = [NSString stringWithFormat:@"The text of the attribute '%@' doesn't match the required pattern.", attributeName];
                        break;
                    default:
                        msg = [NSString stringWithFormat:@"Unknown error (code %@).", @(error.code)];
                        break;
                }
                
                messages = [messages stringByAppendingFormat:@"%@%@%@\n", (entityName?:@""),(entityName?@": ":@""),msg];
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Validation Error"
                                                            message:messages
                                                           delegate:nil
                                                  cancelButtonTitle:nil otherButtonTitles:@"ok", nil];
            [alert show];
        }
    }
}

-(BOOL)deleteObject:(id)object {
    NSManagedObjectContext * moc = self.mainObjectContext;
    if (![moc isEqual:self.currentObjectContext]) {
        NSLog(@"#ERROR: deleteObject called from wrong context");
        return NO;
    }
    return [self deleteObject:object inContext:moc];
}

-(BOOL)deleteObject:(id)object inContext:(NSManagedObjectContext *) context {

    if (TRACE_DELETES) NSLog(@"deleteObject called from %@", [NSThread callStackSymbols]);
    if (object != nil) {
        if ([object isKindOfClass:[NSManagedObject class]]) {
            NSManagedObject * mo = object;
            if (![mo.managedObjectContext isEqual:context]) {
                NSLog(@"#ERROR: deleteObject: bad context for object %@", object);
                return false;
            }
            if (mo.isDeleted) {
                NSLog(@"#WARNING: deleteObject: deletion call for deleted object entity ‘%@‘ id ‘%@‘", mo.entity.name, mo.objectID.URIRepresentation);
            }
            if (TRACE_DELETES) NSLog(@"deleteObject: deleting object of entity %@ id %@", mo.entity.name, mo.objectID.URIRepresentation);
            [context deleteObject:mo];
            if (TRACE_DELETES) NSLog(@"deleteObject: done");
            return true;
        } else {
            NSLog(@"#ERROR: deleteObject: not a NSManagedObject");
        }
    } else {
        NSLog(@"#ERROR: deleteObject: nil");
    }
    return false;
}

// returns NO when a managed object still is in the database and
// YES if it has either been marked for deletion or has been deleted from the database
- (BOOL)hasManagedObjectBeenDeleted:(NSManagedObject *)managedObject {
    
    if (managedObject.isDeleted) {
        return YES;
    }
    
    NSManagedObjectContext *moc = [self mainObjectContext];
    
    NSManagedObjectID   *objectID           = [managedObject objectID];
    NSManagedObject     *managedObjectClone = [moc existingObjectWithID:objectID error:NULL];
    
    if (!managedObjectClone) {
        return YES;                 // Deleted.
    } else {
        return NO;                  // Not deleted.
    }
}

- (void)saveDatabase
{
    NSString * savePolicy = [[HXOUserDefaults standardUserDefaults] objectForKey: kHXOSaveDatabasePolicy];
    if (![savePolicy isEqualToString:kHXOSaveDatabasePolicyDelayed]) {
        [self saveContext];
        return;
    }

    [self.nextDatabaseSaveTimer invalidate];
    
    //NSTimeInterval lastPendingProcessed = [[NSDate new] timeIntervalSinceDate:self.lastPendingChangesProcessed];
    //NSLog(@"lastPendingProcessed ago %f",lastPendingProcessed);
    //if (lastPendingProcessed > 2.0, YES) {
    //    [self doProcessPendingChangesNow:YES];
    //} else {
    //    if (self.nextChangeProcessTimer == nil) {
    //        self.nextChangeProcessTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(doProcessPendingChanges) userInfo:nil repeats:NO];
    //    }
    //}

    [self doProcessPendingChangesNow:YES];

    
    const double minDatabaseSaveInterval = 5.0;
    const double nextDatabaseSaveInterval = 6.0;
    // NSLog(@"lastDatebaseSaveDate interval %f",[self.lastDatebaseSaveDate timeIntervalSinceNow]);
    if (self.lastDatebaseSaveDate != nil) {
        if (-[self.lastDatebaseSaveDate timeIntervalSinceNow] < minDatabaseSaveInterval) {
            self.nextDatabaseSaveTimer = [NSTimer scheduledTimerWithTimeInterval:nextDatabaseSaveInterval target:self selector:@selector(saveDatabase) userInfo:nil repeats:NO];
            return;
        }
    }
    [self saveContext];
    self.lastDatebaseSaveDate = [NSDate date];
    self.lastPendingChangesProcessed = self.lastDatebaseSaveDate;
    // NSLog(@"Saved database at %@",self.lastDatebaseSaveDate);
}

- (void)doProcessPendingChangesNow:(BOOL)now {
    NSTimeInterval lastPendingProcessed = [[NSDate new] timeIntervalSinceDate:self.lastPendingChangesProcessed];
    if (now || lastPendingProcessed > 2.0) {
        if (TRACE_PENDING_CHANGES) NSLog(@"process pending changes started");
        NSDate * pendingChangesProcessingStart = [NSDate new];
        [self.mainObjectContext processPendingChanges]; // will perform all UI changes
        NSDate * pendingChangesProcessingStop = [NSDate new];
        if (TRACE_PENDING_CHANGES) NSLog(@"process pending changes took %1.3f secs.",[pendingChangesProcessingStop timeIntervalSinceDate:pendingChangesProcessingStart]);
        self.lastPendingChangesProcessed = [NSDate new];
    }
    self.nextChangeProcessTimer = nil;
}


- (void)saveDatabaseNow
{
    [self.nextDatabaseSaveTimer invalidate];
    self.nextDatabaseSaveTimer = nil;
    [self saveContext];
    self.lastDatebaseSaveDate = [NSDate date];
    self.lastPendingChangesProcessed = self.lastDatebaseSaveDate;
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)mainObjectContext
{
    if (_mainObjectContext != nil) {
        return _mainObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _mainObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainObjectContext setPersistentStoreCoordinator:coordinator];
        [_mainObjectContext setUndoManager: nil];
        //[_mainObjectContext setRetainsRegisteredObjects:YES];
        [NSThread currentThread].threadDictionary[@"hxoMOContext"] = _mainObjectContext;
    }
    return _mainObjectContext;
}

- (NSManagedObjectContext *)currentObjectContext
{
    return [NSThread currentThread].threadDictionary[@"hxoMOContext"];
}

-(void) assertMainContext {
    if (![self.currentObjectContext isEqual:self.mainObjectContext]) {
        NSLog(@"#ERROR: assertMainContext: called from a background thread");
        NSLog(@"%@", [NSThread callStackSymbols]);
    }
}

- (NSManagedObjectContext *)newBackgroundManagedObjectContext {
    if (![self.currentObjectContext isEqual:self.mainObjectContext]) {
        NSLog(@"ERROR: calling newBackgroundManagedObjectContext from another background context is not allowed");
        NSLog(@"%@", [NSThread callStackSymbols]);
        return nil;
    }
    NSManagedObjectContext *temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    temporaryContext.parentContext = [self mainObjectContext];
    [temporaryContext setUndoManager: nil];
    return temporaryContext;
}

- (void)performWithoutLockingInNewBackgroundContext:(ContextBlock)backgroundBlock {
    NSManagedObjectContext *temporaryContext = [self newBackgroundManagedObjectContext];
    if (temporaryContext != nil) {
        NSManagedObjectContext * mainMOC = [self mainObjectContext];
        [temporaryContext performBlock:^{
            [NSThread currentThread].threadDictionary[@"hxoMOContext"] = temporaryContext;
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Starting backgroundblock of ctx %@", temporaryContext);
            backgroundBlock(temporaryContext);
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished backgroundblock of ctx %@, pushing to parent", temporaryContext);
            
            // push to parent
            [self saveContext:temporaryContext];
            
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished saving to parent of ctx %@, pushing done", temporaryContext);
            
            // save parent to disk asynchronously
            [mainMOC performBlock:^{
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes of ctx %@,", temporaryContext);
                [self saveDatabaseNow];
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes done of ctx %@,", temporaryContext);
            }];
            [[NSThread currentThread].threadDictionary removeObjectForKey:@"hxoMOContext"];
        }];
    }
}

-(NSLock*)idLock:(NSString*)name {
    if (name == nil) {
        NSLog(@"#ERROR: idLock called with nil name, stack=%@", [NSThread callStackSymbols]);
        name = @"NIL-LOCK";
    }

    @synchronized(_idLocks) {
        NSLock * lock = _idLocks[name];
        if (lock != nil) {
            if (TRACE_LOCKING) NSLog(@"handing out lock %@",lock);
            return lock;
        }
        lock = [NSLock new];
        lock.name = name;
        _idLocks[name] = lock;
        if (TRACE_LOCKING) NSLog(@"handing out new lock %@",lock);
        return lock;
    }
}

- (void)performWithLockingId:(const NSString*)lockId inNewBackgroundContext:(ContextBlock)backgroundBlock  {
    if (lockId == nil) {
        NSLog(@"#ERROR: performWithLockingId called with nil lockId, stack=%@", [NSThread callStackSymbols]);
        lockId = @"NIL-LOCK";
    }
    
    // TODO: get rid of unused contexts
    NSManagedObjectContext *temporaryContext = [self backGroundContextForId:lockId];
    if (temporaryContext != nil) {
        NSManagedObjectContext * mainMOC = [self mainObjectContext];
        [temporaryContext performBlock:^{
            if (TRACE_LOCKING) NSLog(@"performing on queue %@",lockId);
            
            [temporaryContext reset]; // load any changes in the parent context after lock acquisition
            
            [NSThread currentThread].threadDictionary[@"hxoMOContext"] = temporaryContext;
            
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Starting backgroundblock of ctx %@ lockid %@", temporaryContext, lockId);
            
            backgroundBlock(temporaryContext);
            
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished backgroundblock of ctx %@, pushing to parent lockid %@", temporaryContext, lockId);
            
            // push to parent
            if ([temporaryContext hasChanges]) {
                [self saveContext:temporaryContext];
                
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished saving to parent of ctx %@, pushing done lockid %@", temporaryContext, lockId);
                
                // save parent to disk
                [mainMOC performBlockAndWait:^{
                    if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes of ctx %@, lockid %@", temporaryContext, lockId);
                    [self saveDatabaseNow];
                    if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes done of ctx %@, lockid %@", temporaryContext, lockId);
                }];
            } else {
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"No uncommited changes for backgroundblock of ctx %@,  lockid %@", temporaryContext, lockId);
            }
            [[NSThread currentThread].threadDictionary removeObjectForKey:@"hxoMOContext"];
        }];
    }
}

- (NSManagedObjectContext*) backGroundContextForId:(const NSString*)name {
    
    if (name == nil) {
        NSLog(@"#ERROR: backGroundContextForId called with nil name, stack=%@", [NSThread callStackSymbols]);
        name = @"NIL-CONTEXT";
    }
    
    @synchronized(_backgroundContexts) {
        NSManagedObjectContext * context = _backgroundContexts[name];
        if (context != nil) {
            if (TRACE_LOCKING) NSLog(@"handing out context %@ for name %@", context, name);
            return context;
        }
        context = [self newBackgroundManagedObjectContext];
        _backgroundContexts[name] = context;
        if (TRACE_LOCKING) NSLog(@"handing out new context %@ for name %@",context, name);
        return context;
    }
}
/*
- (void)performWithLockingIdX:(NSString*)lockId inNewBackgroundContext:(ContextBlock)backgroundBlock  {
    if (lockId == nil) {
        NSLog(@"#ERROR: performWithLockingId called with nil lockId, stack=%@", [NSThread callStackSymbols]);
        lockId = @"NIL-LOCK";
    }
    
    NSManagedObjectContext *temporaryContext = [self newBackgroundManagedObjectContext];
    if (temporaryContext != nil) {
        NSManagedObjectContext * mainMOC = [self mainObjectContext];
        [temporaryContext performBlock:^{
            NSLock * lock = [self idLock:lockId];
            if (TRACE_LOCKING) NSLog(@"acquiring lock %@",lock);
            [lock lock];
            if (TRACE_LOCKING) NSLog(@"acquired lock %@",lock);
            [temporaryContext reset]; // load any changes in the parent context after lock acquisition
            [NSThread currentThread].threadDictionary[@"hxoMOContext"] = temporaryContext;
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Starting backgroundblock of ctx %@", temporaryContext);
            backgroundBlock(temporaryContext);
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished backgroundblock of ctx %@, pushing to parent", temporaryContext);
            
            // push to parent
            [self saveContext:temporaryContext];
            
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished saving to parent of ctx %@, pushing done", temporaryContext);
            
            // save parent to disk asynchronously
            //[mainMOC performBlockAndWait:^{
            [mainMOC performBlockAndWait:^{
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes of ctx %@,", temporaryContext);
                [self saveDatabaseNow];
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes done of ctx %@,", temporaryContext);
                //[temporaryContext performBlock:^{
                //}];
            }];
            [[NSThread currentThread].threadDictionary removeObjectForKey:@"hxoMOContext"];
            if (TRACE_LOCKING) NSLog(@"releasing lock %@",lock);
            [lock unlock];
            if (TRACE_LOCKING) NSLog(@"released lock %@",lock);
        }];
    }
}
 */
/*
-(void)lockId:(NSString*)Id {
    [[self idLock:Id] lock];
}

-(void)unlockId:(NSString*)Id {
    [[self idLock:Id] unlock];
}
*/

/*
- (void)performWithLockingId:(NSString*)lockId inMainContext:(ContextBlock)contextBlock {
    NSManagedObjectContext * mainMOC = [self mainObjectContext];
    [mainMOC performBlock:^{
        NSLock * lock = [self idLock:lockId];
        if (TRACE_LOCKING) NSLog(@"maincontext acquiring lock %@",lock);
        [lock lock];
        if (TRACE_LOCKING) NSLog(@"maincontext acquired lock %@",lock);
        contextBlock(mainMOC);
        if (TRACE_LOCKING) NSLog(@"maincontext releasing lock %@",lock);
        [lock unlock];
        if (TRACE_LOCKING) NSLog(@"maincontext released lock %@",lock);
    }];
}
*/

NSArray * objectIds(NSArray* managedObjects) {
    NSError * error = nil;
    [AppDelegate.instance.currentObjectContext obtainPermanentIDsForObjects:managedObjects error:&error];
    if (error == nil) {
        NSMutableArray * result = [NSMutableArray new];
        for (NSManagedObject * obj in managedObjects) {
            [result addObject:obj.objectID];
        }
        return result;
    } else {
        NSLog(@"could not obtain permanent ids for managed objects, error=%@", error);
    }
    return nil;
}

NSArray * permanentObjectIds(NSArray* managedObjects) {
    NSManagedObjectContext * currentContext = AppDelegate.instance.currentObjectContext;
    NSArray * inserted = currentContext.insertedObjects.allObjects;
    if (inserted.count > 0) {
        NSError * error = nil;
        [currentContext obtainPermanentIDsForObjects:inserted error:&error];
        if (error != nil) {
            NSLog(@"Could not obtain permanent ids for inserted objects, error=%@", error);
            return nil;
        }
    }
    NSError * error = nil;
    [currentContext obtainPermanentIDsForObjects:managedObjects error:&error];
    if (error == nil) {
        NSMutableArray * result = [NSMutableArray new];
        for (NSManagedObject * obj in managedObjects) {
            [result addObject:obj.objectID];
        }
        return result;
    } else {
        NSLog(@"permanentObjectIds: could not obtain permanent ids for managed objects, error=%@", error);
    }
    return nil;
}

NSArray * managedObjects(NSArray* objectIds, NSManagedObjectContext * context) {
    NSMutableArray * result = [NSMutableArray new];
    NSError * error = nil;
    for (NSManagedObjectID * objId in objectIds) {
        //NSManagedObject *  obj = [context existingObjectWithID:objId error:&error];
        NSManagedObject *  obj = [context objectWithID:objId];
        if (obj == nil || error != nil) {
            NSLog(@"managedObjects: could not fetch managed object from id %@, error=%@", objId, error);
            return nil;
        }
        [result addObject:obj];
    }
    return result;
}

NSArray * existingManagedObjects(NSArray* objectIds, NSManagedObjectContext * context) {
    NSMutableArray * result = [NSMutableArray new];
    NSError * error = nil;
    int num = 0;
    for (NSManagedObjectID * objId in objectIds) {
        NSManagedObject *  obj = [context existingObjectWithID:objId error:&error];
        if (obj == nil || error != nil) {
            NSLog(@"existingManagedObjects: could not fetch managed object %d from id %@, error=%@", num, objId, error);
            return nil;
        }
        [result addObject:obj];
        num++;
    }
    return result;
}

// our temporary background context is a serial context, so calling this method will result in this block excecuted after
// the temporary context has finished it's main processing
- (void)performAfterCurrentContextFinishedInMainContext:(ContextBlock)contextBlock {
    NSManagedObjectContext * currentContext = self.currentObjectContext;
    if ([currentContext isEqual:self.mainObjectContext]) {
        NSLog(@"performAfterCurrentContextFinishedInMainContext called from main context, don't do that");
    }
    [currentContext performBlock:^{
        NSManagedObjectContext * mainMOC = [self mainObjectContext];
        [mainMOC performBlock:^{
            contextBlock(mainMOC);
        }];
    }];
}

- (void)performAfterCurrentContextFinishedInMainContextPassing:(NSArray*)objects withBlock:(ContextParameterBlock)contextBlock {
    NSManagedObjectContext * currentContext = self.currentObjectContext;
    if ([currentContext isEqual:self.mainObjectContext]) {
        NSLog(@"performAfterCurrentContextFinishedInMainContext called from main context, don't do that");
    }
    NSArray * inserted = currentContext.insertedObjects.allObjects;
    if (inserted.count > 0) {
        NSError * error = nil;
        [currentContext obtainPermanentIDsForObjects:inserted error:&error];
        if (error != nil) {
            NSLog(@"Could not obtain permanent ids for inserted objects, error=%@", error);
        }
    }
    [currentContext performBlock:^{
        NSArray * ids = objectIds(objects);

        NSManagedObjectContext * mainMOC = [self mainObjectContext];
        [mainMOC performBlock:^{
            //[self saveContext:mainMOC];
            //contextBlock(mainMOC, managedObjects(ids, mainMOC));
            NSArray * objects = existingManagedObjects(ids, mainMOC);
            if (objects != nil) {
                contextBlock(mainMOC, objects);
            } else {
                NSLog(@"Could not execute block in main context, parameter objects not available");
            }
        }];
    }];
}

- (void)performWithoutLockingInMainContext:(ContextBlock)contextBlock {
    NSManagedObjectContext * mainMOC = [self mainObjectContext];
    [mainMOC performBlock:^{
        contextBlock(mainMOC);
    }];
}
/*

- (void)performInMainContextAndWait:(ContextBlock)contextBlock {
    NSManagedObjectContext * mainMOC = [self mainObjectContext];
    [mainMOC performBlockAndWait:^{
        contextBlock(mainMOC);
    }];
}
*/

-(void)saveContext:(NSManagedObjectContext*)context {
    NSDate * start;
    if (TRACE_BACKGROUND_PROCESSING) {
        NSLog(@"Saving context %@", context);
        start = [[NSDate alloc] init];
    }
    NSError *error = nil;
    if (TRACE_CONTACT_SAVES) [self checkObjectsInContextForContacts:context info:[NSString stringWithFormat:@"saving context %@", context]];
    if ([context hasChanges] && ![context save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        ++validationErrorCount;
        if (validationErrorCount < 3 || [context isEqual:self.mainObjectContext]) {
            [self performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
                [self displayValidationError:error];
            }];
        } else {
            [self performWithoutLockingInMainContext:^(NSManagedObjectContext *context) {
                [self showFatalErrorAlertWithMessage:nil withTitle:nil];
            }];
        }
    }
    if (start && TRACE_BACKGROUND_PROCESSING) {
        double elapsed = -[start timeIntervalSinceNow];
        NSLog(@"Saving context %@ took %f secs", context, elapsed);
    }
    
}


// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"HoccerXO" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSManagedObjectModel *)managedObjectModelWithName:(NSString*)modelName
{
    //NSURL *modelURL = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"mom"];
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"mom" subdirectory:@"HoccerXO.momd"];
    if (MIGRATION_DEBUG) NSLog(@"modelURL=%@", modelURL);
    NSManagedObjectModel * myManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return myManagedObjectModel;
}

- (NSArray*) urlsForAllModelVersions {
    return [[NSBundle mainBundle] URLsForResourcesWithExtension:@"mom" subdirectory:@"HoccerXO.momd"];
}

- (NSManagedObjectModel *)rpcObjectModel
{
    if (_rpcObjectModel != nil) {
        return _rpcObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"RPCObjectsModel" withExtension:@"momd"];
    _rpcObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _rpcObjectModel;
}

// #define BINSTORE
#ifndef BINSTORE
- (NSString *)storeFileSuffix {
    return @"sqlite";
}
- (NSString *)storeType {
    return NSSQLiteStoreType;
}
#else
- (NSString *)storeFileSuffix {
    return @"binstore";
}

- (NSString *)storeType {
    return NSBinaryStoreType;
}
#endif


- (NSURL *)persistentStoreURL {
    NSString * databaseName = [NSString stringWithFormat: @"%@.%@", [[Environment sharedEnvironment] suffixedString: @"HoccerXO"],[self storeFileSuffix]];
    NSURL *storeURL = [[self applicationLibraryDirectory] URLByAppendingPathComponent: databaseName];
    return storeURL;
}

- (NSURL *)tempPersistentStoreURL {
    NSString * databaseName = [NSString stringWithFormat: @"_%@.%@", [[Environment sharedEnvironment] suffixedString: @"HoccerXO"],[self storeFileSuffix]];
    NSURL *storeURL = [[self applicationLibraryDirectory] URLByAppendingPathComponent: databaseName];
    return storeURL;
}

- (NSURL *)oldPersistentStoreURL {
    NSString * databaseName = [NSString stringWithFormat: @"%@.%@", [[Environment sharedEnvironment] suffixedString: @"HoccerXO"],[self storeFileSuffix]];
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: databaseName];
    return storeURL;
}

- (NSURL *)preferencesURL {
    NSString * bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSString * preferencesName = [NSString stringWithFormat: @"Preferences/%@.plist", bundleId];
    NSURL *prefURL = [[self applicationLibraryDirectory] URLByAppendingPathComponent: preferencesName];
    return prefURL;
}

- (BOOL) needsEulaAcceptance {
    return [self eulaURL] && ! [[self eulaVersion] isEqualToString: [self acceptedEulaVersion]];
}
- (NSURL*)eulaURL {
    NSString * bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSString * eulaName = [NSString stringWithFormat: @"eula-%@", bundleId];
    return [[NSBundle mainBundle] URLForResource: eulaName withExtension:@"rtf"];
}

- (NSString*) eulaVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"HXOEulaVersion"];
}

- (NSString*) acceptedEulaVersion {
    return [[NSUserDefaults standardUserDefaults] stringForKey: @"AcceptedEulaVersion"];
}
- (NSURL *)cacheFileURL:(NSString*)cacheName {
    NSString * fileName = [NSString stringWithFormat: @"%@.%@", [[Environment sharedEnvironment] suffixedString: cacheName],@"hcache"];
    NSURL *fileURL = [[self applicationLibraryDirectory] URLByAppendingPathComponent: fileName];
    return fileURL;
}


- (BOOL) canAutoMigrateFrom:(NSString*)modelName {
    return [self canAutoMigrateFromModel:[self managedObjectModelWithName:modelName]];
}

- (BOOL) canAutoMigrateFromModel:(NSManagedObjectModel*)fromModel {
    NSError * outError;
    NSManagedObjectModel * toModel = [self managedObjectModel];
    NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:fromModel destinationModel:toModel error:&outError];
    
    // If Core Data cannot create an inferred mapping model, return NO.
    
    if (!mappingModel) {
        if (MIGRATION_DEBUG) NSLog(@"canAutoMigrateFrom: Error=%@", outError);
        return NO;
    }
    if (MIGRATION_DEBUG) NSLog(@"Mapping model = %@", mappingModel);
    return YES;
}

- (BOOL) compatibilityOfStore:(NSURL *)sourceStoreURL withModel:(NSManagedObjectModel*)destinationModel {
    NSError *myError = nil;
    
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:[self storeType] URL:sourceStoreURL error:&myError];
    
    if (sourceMetadata == nil) {
        NSLog(@"Error obtaining store metadata for url %@, error %@, %@", sourceStoreURL, myError, [myError userInfo]);
    }
    NSString *configuration = nil;
    BOOL pscCompatibile = [destinationModel isConfiguration:configuration compatibleWithStoreMetadata:sourceMetadata];
    
    if (pscCompatibile) {
        return YES;
    }
    return NO;
}

- (NSManagedObjectModel *) findModelForStore:(NSURL*)storeURL {
    NSArray * myModelUrls = [self urlsForAllModelVersions];
    NSManagedObjectModel * result = nil;
    for (NSURL * url in myModelUrls) {
        if (MIGRATION_DEBUG) NSLog(@"Checking model %@", url);
        NSManagedObjectModel * myModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        if ([self compatibilityOfStore:storeURL withModel:myModel]) {
            result = myModel;
            if (MIGRATION_DEBUG) NSLog(@"is compatible");
        } else {
            if (MIGRATION_DEBUG) NSLog(@"not compatible");
        }
    }
    return result;
}

- (BOOL)migrateStoreFromURL:(NSURL*)sourceStoreURL
                      toURL:(NSURL*)destinationStoreURL
                withMapping:(NSMappingModel*)mappingModel
                withManager:(NSMigrationManager*)migrationManager
{
    NSDictionary *sourceStoreOptions = nil;
    NSDictionary *destinationStoreOptions = nil;
    NSError *myError = nil;
    
    if (MIGRATION_DEBUG) NSLog(@"mappingModel = %@", mappingModel);
    
    BOOL ok = [migrationManager migrateStoreFromURL:sourceStoreURL
                                               type:[self storeType]
                                            options:sourceStoreOptions
                                   withMappingModel:mappingModel
                                   toDestinationURL:destinationStoreURL
                                    destinationType:[self storeType]
                                 destinationOptions:destinationStoreOptions
                                              error:&myError];
    if (myError != nil) {
        NSLog(@"Migration Error: %@", myError);
    }
    return ok;
}

- (NSPersistentStoreCoordinator *)newPersistentStoreCoordinatorWithURL:(NSURL *)storeURL {

    NSError *myError = nil;
    NSURL * oldURL = [self oldPersistentStoreURL];
    NSString * myPath = [storeURL path];
    NSString * oldPath = [oldURL path];
    if ([[NSFileManager defaultManager] fileExistsAtPath:oldPath]) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:myPath]) {
            [[NSFileManager defaultManager] moveItemAtURL:oldURL toURL:storeURL error:&myError];
            if (myError != nil) {
                NSLog(@"Error moving old database from %@ to %@, error=%@", oldURL, storeURL, myError);
            }
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:oldURL error:&myError];
            if (myError != nil) {
                NSLog(@"Error removing database at old URL %@, error=%@", oldURL, myError);
            } else {
                NSLog(@"Removed old database at URL %@", oldURL);
            }
        }
    }
    NSURL * tmpURL = [self tempPersistentStoreURL];
    NSString * tmpPath = [tmpURL path];
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtURL:tmpURL error:&myError];
        if (myError != nil) {
            NSLog(@"Error removing database at tmp URL %@, error=%@", tmpURL, myError);
        } else {
            NSLog(@"Removed tmp database at URL %@", tmpURL);
        }
    }
    
    if (MIGRATION_DEBUG) NSLog(@"attributes=%@",[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:&myError]);
    if (myError != nil) {
        NSLog(@"Error getting attributes from %@, error=%@", myPath, myError);
    }
    
    NSDictionary *migrationOptions = nil;
#if 0
    if ([[NSFileManager defaultManager] fileExistsAtPath:myPath]) {
        
        NSManagedObjectModel * storeModel = [self findModelForStore:storeURL];
        if (!storeModel) {
            NSLog(@"#Fatal Error, no model compatible with existing store found, migration will not work");
            return nil;
        }
        
        NSManagedObjectModel * latestModel = [self managedObjectModel];
        if (![self compatibilityOfStore:storeURL withModel:latestModel]) {
            // migration needed
            
            NSError * outError;
            NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:storeModel destinationModel:latestModel error:&outError];
/*
            NSString * mappingModelName = @"MappingModel-17-18";
            NSURL *fileURL = [[NSBundle mainBundle] URLForResource:mappingModelName withExtension:@"cdm"];
            NSMappingModel *mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:fileURL];
*/            
            if (mappingModel == nil) {
                NSLog(@"Can not automigrate, need special migration");
                return nil;
            }
            if (MIGRATION_DEBUG) NSLog(@"Automigration possible");
            migrationOptions = @{NSMigratePersistentStoresAutomaticallyOption : @(YES),
                                 NSInferMappingModelAutomaticallyOption : @(YES),
                                 NSSQLitePragmasOption : @{@"journal_mode" : @"DELETE"}};
            
            
            NSURL * newStoreURL = [self tempPersistentStoreURL];
            NSMigrationManager * migrationManager = [[NSMigrationManager alloc] initWithSourceModel:storeModel destinationModel:latestModel];
            if ([self migrateStoreFromURL:storeURL toURL:newStoreURL withMapping:mappingModel withManager:migrationManager]) {
                
                [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&myError];
                if (myError != nil) {
                    NSLog(@"Error removing database at %@ after migration, error=%@", storeURL, myError);
                    return nil;
                }
                [[NSFileManager defaultManager] moveItemAtURL:newStoreURL toURL:storeURL error:&myError];
                if (myError != nil) {
                    NSLog(@"Error moving database from %@ to %@ after migration, error=%@", newStoreURL, storeURL, myError);
                    return nil;
                }
                
                migrationOptions = nil; // do not attempt to automigrate, we did that already
            } else {
                NSLog(@"Migration failed.");
            }
        }
    }
#endif
    if (migrationOptions == nil) {
        migrationOptions = @{NSMigratePersistentStoresAutomaticallyOption : @(YES),
                             NSInferMappingModelAutomaticallyOption : @(YES),
                             NSSQLitePragmasOption : @{@"journal_mode" : @"DELETE"}};
    }
    
    NSPersistentStoreCoordinator * theNewStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    if (![theNewStoreCoordinator addPersistentStoreWithType:[self storeType] configuration:nil URL:storeURL options:migrationOptions error:&myError]) {

        NSLog(@"Unresolved error %@, %@", myError, [myError userInfo]);
        return nil;
    }
    return theNewStoreCoordinator;
    
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }

    NSURL *storeURL = [self persistentStoreURL];

    _persistentStoreCoordinator = [self newPersistentStoreCoordinatorWithURL:storeURL];
    
    if (_persistentStoreCoordinator == nil) {
        [self showDeleteDatabaseAlertWithMessage:@"The database format has been changed by the developers. Your database must be deleted to continue. Do you want to delete your database?" withTitle:@"Database too old"];
    }
    
    return _persistentStoreCoordinator;
}

- (void) deleteDatabase {
    NSURL *storeURL = [self persistentStoreURL];
    [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
    [[HXOUserDefaults standardUserDefaults] setBool: NO forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]; // enforce first run, otherwise you lose your credentials
    // TODO: delete or recover stored files
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDirectory {
    if (_applicationDirectory == nil) {
        _applicationDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSUserDomainMask] lastObject];
    }
    return _applicationDirectory;
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory {
    if (_applicationDocumentDirectory == nil) {
        _applicationDocumentDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    }
    return _applicationDocumentDirectory;
}

- (NSURL *)applicationTemporaryDocumentsDirectory {
    if (_applicationTemporaryDocumentDirectory == nil) {
        NSURL * tmpdirOld = [self.applicationDocumentsDirectory URLByAppendingPathComponent:@"temporary" isDirectory:YES];
        NSURL * tmpdir = [self.applicationDocumentsDirectory URLByAppendingPathComponent:@".temporary" isDirectory:YES];
        
        BOOL isDirectory = NO;
        BOOL create = NO;
        NSError * error = nil;

        if ([[NSFileManager defaultManager] fileExistsAtPath:[tmpdirOld path] isDirectory:&isDirectory]) {
            if (isDirectory) {
                [[NSFileManager defaultManager] moveItemAtURL:tmpdirOld toURL:tmpdir error:&error];
                if (error != nil) {
                    NSLog(@"#ERROR: item at %@ can't be moved to %@", tmpdirOld, tmpdir);
                    return nil;
                }
            }
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[tmpdir path] isDirectory:&isDirectory]) {
            create = YES;
        } else {
            if (!isDirectory) {
                NSError * error = nil;
                [[NSFileManager defaultManager] removeItemAtURL:tmpdir error:&error];
                if (error != nil) {
                    NSLog(@"#ERROR: item at %@ is not a directory and can't be removed", tmpdir);
                    return nil;
                }
                create = YES;
            }
        }
        if (create) {
            NSError * error = nil;
            NSLog(@"Creating directory for temporary file at %@", tmpdir);
            
            [[NSFileManager defaultManager] createDirectoryAtURL:tmpdir withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions: @(0755)} error:&error];
            if (error != nil) {
                NSLog(@"#ERROR: temporary directory at %@ can not be created", tmpdir);
                return nil;
            }
        }
        _applicationTemporaryDocumentDirectory = tmpdir;
    }
    return _applicationTemporaryDocumentDirectory;
}

- (NSURL *) applicationLibraryDirectory {
    if (_applicationLibraryDirectory == nil) {
        _applicationLibraryDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    }
    return _applicationLibraryDirectory;
}

#pragma mark - Application's user Agent string for http request

- (NSString *) userAgent {
	if (userAgent == nil) {
        userAgent = [NSString stringWithFormat: @"%@ %@ %@ / %@ / %@ %@",
                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                     [UIDevice currentDevice].model,
                     [UIDevice currentDevice].systemName,
                     [UIDevice currentDevice].systemVersion];
	}
	return userAgent;
}

#pragma mark - Message Count Handling

- (NSUInteger) unreadMessageCount {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName: [HXOMessage entityName] inManagedObjectContext: self.currentObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isReadFlag == NO"];

    NSError *error = nil;
    NSUInteger numberOfRecords = [self.currentObjectContext countForFetchRequest:fetchRequest error:&error];

    if (numberOfRecords == NSNotFound) {
        NSLog(@"ERROR: unreadMessageCount: failed to count unread messages: %@", error);
        abort();
    }
    return numberOfRecords;
}

- (void) updateUnreadMessageCountAndStop {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        NSLog(@"#WARNING: updateUnreadMessageCountAndStop: already excuting background task, doing nothing");
        return;
    }
    NSUInteger unreadMessages = [self unreadMessageCount];
    [UIApplication sharedApplication].applicationIconBadgeNumber = unreadMessages;
    
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"#WARNING: Running background expiration handler");
        [self.chatBackend stop];
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }];

    if (self.chatBackend.isLoggedIn) {
    
        // Start the long-running task and return immediately.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.chatBackend hintApnsUnreadMessage: unreadMessages handler: ^(BOOL success){
                if (CONNECTION_TRACE) NSLog(@"updated unread message count: %@", success ? @"success" : @"failed");
                __weak AppDelegate * weakSelf = self;
                [self setBackgroundFinalizer:^{
                    NSLog(@"#INFO: Executing background finalizer in updateUnreadMessageCountAndStop");
                    if (weakSelf.chatBackend.isLoggedIn) {
                        NSLog(@"#INFO: Still logged in, stopping backend");
                        [weakSelf.chatBackend stop];
                    } else {
                        NSLog(@"#INFO: No longer logged in, stopping immediately");
                        [weakSelf.chatBackend stop];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf backendDidStop];
                        });
                    }
                }];
            }];
        });
    } else {
        __weak AppDelegate * weakSelf = self;
        [self setBackgroundFinalizer:^{
            NSLog(@"#INFO: Not logged in, stopping immediately");
            [weakSelf.chatBackend stop];
            [weakSelf backendDidStop];
        }];
    }
}

#pragma mark - Apple Push Notifications

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if (deviceToken != nil) {
        NSLog(@"got APNS deviceToken: %@ ", [deviceToken hexadecimalString]);
        // TODO: do we need this?
        //self.registered = YES;
        NSString * tokenString = [deviceToken hexadecimalString];
        [[HXOUserDefaults standardUserDefaults] setValue: tokenString forKey: kHXOAPNDeviceToken];
        [self.chatBackend gotAPNSDeviceToken: tokenString];
    } else {
        NSLog(@"ERROR: APN device token is nil");
    }
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error in APN registration. Error: %@", err);
}


- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
    NSLog(@"handleActionWithIdentifier %@", identifier);
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSLog(@"didReceiveLocalNotification %@", notification.userInfo);
    NSLog(@"didReceiveLocalNotification: backend state = %@", HXOBackend.instance.stateString);
    self.openNotificationInfo = notification.userInfo;
    if (self.tabBarController != nil) {
        self.tabBarController.selectedIndex = 0;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"openHXOMessage"
                                                        object:self
                                                      userInfo:notification.userInfo
     ];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler
{
    NSLog(@"didReceiveRemoteNotification %@", userInfo);

    if(application.applicationState == UIApplicationStateInactive) {
        NSLog(@"didReceiveRemoteNotification: app state INACTIVE");
    } else if(application.applicationState == UIApplicationStateActive) {
        NSLog(@"didReceiveRemoteNotification: app state ACTIVE");
    } else if(application.applicationState == UIApplicationStateBackground) {
        NSLog(@"didReceiveRemoteNotification: app state BACKGROUND");
    } else {
        NSLog(@"didReceiveRemoteNotification: ERROR: strange app state %ld", (long)application.applicationState);
    }
    
    if (!self.runningInBackground) {
        NSLog(@"didReceiveRemoteNotification - not running in background");
        if (handler != nil) handler(UIBackgroundFetchResultNoData);
        return;
    }
    
    NSLog(@"didReceiveRemoteNotification: backend state = %@", HXOBackend.instance.stateString);
    
    NSNumber * contentAvailableValue = userInfo[@"aps"][@"content-available"];
    BOOL contentAvailable = contentAvailableValue != nil && contentAvailableValue.intValue == 1;
    NSLog(@"didReceiveRemoteNotification: contentAvailableValue=%@, contentAvailable = %d", contentAvailableValue, contentAvailable);
    
    if (!contentAvailable) {
        NSLog(@"didReceiveRemoteNotification - no content available");
        if (handler != nil) handler(UIBackgroundFetchResultNoData);
        return;
    }
    
    _pushNotificationInfo = userInfo;
    ++_backgroundNotification;
    if (self.environmentMode != ACTIVATION_MODE_NONE) {
        [self suspendEnvironmentMode]; // for resuming nearby mode, the Conversations- or ChatView are responsible; the must do it after login
    }
    if (!HXOBackend.instance.isLoggedIn) {
        NSLog(@"didReceiveRemoteNotification - starting backend");
        [HXOBackend.instance start:NO];
    } else {
        NSLog(@"didReceiveRemoteNotification - backend still active in background");
    }
    if (_backgroundFetchHandler) {
        NSLog(@"didReceiveRemoteNotification - old backgroundFetchHandler still there, executing...");
        _backgroundFetchHandler(UIBackgroundFetchResultNewData);
        _backgroundFetchHandler = nil;
        if (_backgroundFinalizerTriggered) {
            NSLog(@"didReceiveRemoteNotification - old _backgroundFinalizerTriggered triggered, canceling");
            [self cancelFinalizer];
        }
    }
    NSLog(@"didReceiveRemoteNotification - setting new background fetch handler...");
    _backgroundFetchHandler = handler;
}


-(void)finishBackgroundNotificationProcessing {
    NSLog(@"finishBackgroundNotificationProcessing run %ld",_backgroundNotification);
    
    if (_backgroundFetchHandler == nil) {
        NSLog(@"#WARNING: finishBackgroundNotificationProcessing: no _backgroundFetchHandler, doing nothing");
        return;
    }
    
    if (!self.runningInBackground) {
        // we have switched to foreground
        NSLog(@"finishBackgroundNotificationProcessing, running in foreground %ld",_backgroundNotification);
        void (^backgroundFetchHandler)(UIBackgroundFetchResult result) = _backgroundFetchHandler;
        _backgroundFetchHandler = nil;
        if (backgroundFetchHandler) {
            backgroundFetchHandler(UIBackgroundFetchResultNewData);
        }
        _backgroundNotificationReady = _backgroundNotification;
        return;
    }
    
    
    [self saveDatabaseNow];
    [self setLastActiveDate];
    
    _backgroundNotificationReady = _backgroundNotification;
    
    NSUInteger unreadMessages = [self unreadMessageCount];
    [UIApplication sharedApplication].applicationIconBadgeNumber = unreadMessages;
    
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"finishBackgroundNotificationProcessing, running expiration handler %ld",_backgroundNotification);
        [self.chatBackend stop];
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
        NSLog(@"finishBackgroundNotificationProcessing, finishing other background tasks %ld",_backgroundNotification);
        void (^backgroundFetchHandler)(UIBackgroundFetchResult result) = _backgroundFetchHandler;
        _backgroundFetchHandler = nil;
        if (backgroundFetchHandler) {
            backgroundFetchHandler(UIBackgroundFetchResultNewData);
        }
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.chatBackend hintApnsUnreadMessage: unreadMessages handler: ^(BOOL success){
            if (CONNECTION_TRACE, 1) NSLog(@"updated unread message count: %@", success ? @"success" : @"failed");
            __weak AppDelegate * weakSelf = self;
            unsigned long backgroundNotification = _backgroundNotification;
            [self setBackgroundFinalizer:^{
                NSLog(@"Executing background finalizer for notification processing");
                [weakSelf.chatBackend stop];
                void (^backgroundFetchHandler)(UIBackgroundFetchResult result) = AppDelegate.instance->_backgroundFetchHandler;
                AppDelegate.instance->_backgroundFetchHandler = nil;
                if (backgroundFetchHandler) {
                    NSLog(@"finishBackgroundNotificationProcessing, finishing notification background task %ld",backgroundNotification);
                    backgroundFetchHandler(UIBackgroundFetchResultNewData);
                }
            }];
        }];
    });
}

#pragma mark - getTopMostViewController

+ (UIViewController*) getTopMostViewController
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(window in windows) {
            if (window.windowLevel == UIWindowLevelNormal) {
                break;
            }
        }
    }
    
    for (UIView *subView in [window subviews])
    {
        UIResponder *responder = [subView nextResponder];
        
        //added this block of code for iOS 8 which puts a UITransitionView in between the UIWindow and the UILayoutContainerView
        if ([responder isEqual:window])
        {
            //this is a UITransitionView
            if ([[subView subviews] count])
            {
                UIView *subSubView = [subView subviews][0]; //this should be the UILayoutContainerView
                responder = [subSubView nextResponder];
            }
        }
        
        if([responder isKindOfClass:[UIViewController class]]) {
            return [self topViewController: (UIViewController *) responder];
        }
    }
    
    return nil;
}

+ (UIViewController *) topViewController: (UIViewController *) controller
{
    BOOL isPresenting = NO;
    do {
        // this path is called only on iOS 6+, so -presentedViewController is fine here.
        UIViewController *presented = [controller presentedViewController];
        isPresenting = presented != nil;
        if(presented != nil) {
            controller = presented;
        }
        
    } while (isPresenting);
    
    return controller;
}

#pragma mark - Document Interaction

- (BOOL) openWithInteractionController:(NSURL *)myURL withUTI:(NSString*)uti withName:(NSString*)name inView:(UIView*)view withController:(UIViewController*)controller removeFile:(BOOL) removeFileFlag {
    NSLog(@"openWithInteractionController");
    if (self.interactionView != nil) {
        NSLog(@"ERROR: interaction controller busy");
        return NO;
    }
    
    NSLog(@"AppDelegate:openWithInteractionController: uti=%@, name = %@, url = %@", uti, name, myURL);
    self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:myURL];
    self.interactionController.delegate = self;
    self.interactionController.UTI = uti;
    self.interactionController.name = name;
    self.interactionView = view;
    self.interactionViewController = controller;
    self.interactionSending = NO;
    self.interactionRemoveFileFlag = removeFileFlag;
    CGRect navRect = controller.navigationController.navigationBar.frame;
    //navRect.size = CGSizeMake(1500.0f, 40.0f);
    //[self.interactionController presentOpenInMenuFromRect:CGRectNull inView:view animated:YES];
    [self.interactionController presentOpenInMenuFromRect:navRect inView:view animated:YES];
    return YES;
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self.interactionViewController;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller
{
    return self.interactionView;
}

- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller {
    return self.window.frame;
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
    if (!self.interactionSending) {
        NSLog(@"documentInteractionControllerDidDismissOpenInMenu, not sending, cleaning up");
        if (self.interactionRemoveFileFlag) {
            NSError * error = nil;
            [[NSFileManager defaultManager] removeItemAtURL:self.interactionController.URL error:&error];
            if (error == nil) {
                NSLog(@"removed dismissed file URL %@",self.interactionController.URL);
            } else {
                NSLog(@"failed to remove sent file URL %@, error=%@",self.interactionController.URL, error);
            }
        }
        self.interactionView = nil;
        self.interactionViewController = nil;
    } else {
        NSLog(@"documentInteractionControllerDidDismissOpenInMenu, but is sending");
    }
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
    NSLog(@"willBeginSendingToApplication %@", application);
    self.interactionSending = YES;
    self.hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"archive_sending_hud_title", nil)];
    [self.hud show];
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    NSLog(@"didEndSendingToApplication %@", application);
    [self.hud dismiss];
    NSError * error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.interactionController.URL error:&error];
    if (error == nil) {
        NSLog(@"removed sent file URL %@",self.interactionController.URL);
    } else {
        NSLog(@"failed to remove sent file URL %@, error=%@",self.interactionController.URL, error);
    }
    self.interactionView = nil;
    self.interactionViewController = nil;
    self.interactionSending = NO;
}


#pragma mark - URL Handling

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    Environment *environment = [Environment sharedEnvironment];
    if ([[url scheme] isEqualToString:environment.inviteUrlScheme]) {
        // TODO: input verification
        [self.chatBackend acceptInvitation: url.host];
    }
    if ([[url scheme] isEqualToString:@"file"]) {
        NSString *documentType;
        NSError *error;
        if (![url getResourceValue:&documentType forKey:NSURLTypeIdentifierKey error:&error]) {
            NSLog(@"handleOpenURL: could not get documentType, using default, err=%@",error);
            documentType = @"public.data";
        }
        return [self handleFileURL:url withDocumentType:documentType];
    }
    if ([[url scheme] isEqualToString:kHXOTransferCredentialsURLImportScheme]) {
        NSString * host = [url host];
        if ([host isEqualToString:kHXOTransferCredentialsURLCredentialsHost]) {
            // receive only credentials as hex-encoded credentials json
            NSString * hexCredentials = [url lastPathComponent];
            NSLog(@"handleOpenURL: credentials received%@",hexCredentials);
            NSData * credentials = [NSData dataWithHexadecimalString:hexCredentials];
            [self receiveCredentials:credentials];
        } else if ([host isEqualToString:kHXOTransferCredentialsURLArchiveHost]) {
            // receive archive via pasteboard
            [self receiveArchive:url];
        } else {
            NSLog(@"#ERROR: unknown host part for import scheme");
        }
    }
    if ([[url scheme] isEqualToString:kHXOTransferCredentialsURLExportScheme]) {
        NSString * host = [url host];
        if ([host isEqualToString:kHXOTransferCredentialsURLCredentialsHost]) {
            dispatch_async(dispatch_get_main_queue(), ^{ // delay until window is realized
                [self sendCredentials];
            });
        } else if ([host isEqualToString:kHXOTransferCredentialsURLArchiveHost]) {
            dispatch_async(dispatch_get_main_queue(), ^{ // delay until window is realized
                // send archive via pasteboard
                [self transferArchive];
            });
        } else {
            NSLog(@"#ERROR: unknown host part for import scheme");
        }
    }

    return NO;
}

-(void) sendCredentials {
    HXOAlertViewCompletionBlock completion = ^(NSUInteger buttonIndex, UIAlertView * alertView) {
        if (buttonIndex != alertView.cancelButtonIndex) {
            if (![[UserProfile sharedProfile] transferCredentials]) {
                [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"credentials_transfer_failed_no_xox_message",nil)
                                                     withTitle:NSLocalizedString(@"credentials_transfer_failed_no_xox_title",nil)
                                                   withOKBlock:^{
                                                       [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"credentials_transfer_install_app_url",nil)]];
                                                   }];
            }
        }
    };
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"credentials_transfer_safety_question", nil)
                                                     message: nil
                                             completionBlock: completion
                                           cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                           otherButtonTitles: NSLocalizedString(@"transfer", nil),nil];
    [alert show];
}

- (void) receiveCredentials:(NSData*)credentials {
    
    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        switch (buttonIndex) {
            case 0:
                // no
                break;
            case 1: {
                [self.chatBackend disable];
                int result = [[UserProfile sharedProfile] importCredentialsJson:credentials withForce:NO];
                switch (result) {
                    case 1:
                        [[UserProfile sharedProfile] verfierChangePlease];
                        [AppDelegate.instance showFatalErrorAlertWithMessage:NSLocalizedString(@"credentials_imported_message", nil)
                                                                   withTitle:NSLocalizedString(@"credentials_imported_title", nil)];
                        break;
                    case -1:
                        [HXOUI showErrorAlertWithMessageAsync:@"credentials_receive_import_failed_message" withTitle:@"credentials_receive_import_failed_title"];
                        [self.chatBackend enable];
                        break;
                    case 0:
                        [HXOUI showErrorAlertWithMessageAsync:@"credentials_receive_equals_current_message" withTitle:@"credentials_receive_equals_current_title"];
                        [self.chatBackend enable];
                        break;
                    case -2:
                        [HXOUI showErrorAlertWithMessageAsync:@"credentials_receive_old_message" withTitle:@"credentials_receive_old_title"];
                        [self.chatBackend enable];
                        break;
                    default:
                        NSLog(@"#ERROR: receiveCredentials: unhandled result %d", result);
                        break;
                }
            }
                break;
        }
        
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"credentials_received_import_title", nil)
                                                    message: NSLocalizedString(@"credentials_received_import_message", nil)
                                            completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no", nil)
                                          otherButtonTitles:NSLocalizedString(@"credentials_receive_import_btn_title",nil),nil];
    [alert show];
}


-(void) transferArchive {
    HXOAlertViewCompletionBlock completion = ^(NSUInteger buttonIndex, UIAlertView * alertView) {
        if (buttonIndex != alertView.cancelButtonIndex) {
            [self transferArchiveWithHandler:^(BOOL ok) {
                if (!ok) {
                    [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"archive_failed_message",nil)
                                                         withTitle:NSLocalizedString(@"archive_failed_title",nil)
                                                       withOKBlock:^{ }
                     ];
                }
            }];
        }
    };
    long long requiredSpace = [AppDelegate estimatedDocumentArchiveSize] * 2.1;
    long long freeSpace = [AppDelegate freeDiskSpace] + [AppDelegate archiveFileSize];
    
    NSLog(@"transferArchive: required %@, free %@",[AppDelegate memoryFormatter:requiredSpace],[AppDelegate memoryFormatter:freeSpace]);
    
    if (requiredSpace > freeSpace) {
        HXOAlertViewCompletionBlock completion2 = ^(NSUInteger buttonIndex, UIAlertView * alertView) {};
        NSString * archiveNotEnoughSpaceMessage = [NSString stringWithFormat:NSLocalizedString(@"archive_transfer_not_enough_space %@ %@", nil),
                                                   [AppDelegate memoryFormatter:requiredSpace],
                                                   [AppDelegate memoryFormatter:freeSpace]];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_transfer_not_enough_space_title",nil)
                                                         message: archiveNotEnoughSpaceMessage
                                                 completionBlock: completion2
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
        
    } else {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_transfer_safety_question", nil)
                                                         message: nil
                                                 completionBlock: completion
                                               cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                               otherButtonTitles: NSLocalizedString(@"transfer", nil),nil];
        [alert show];
    }
}


- (void)transferArchiveWithHandler:(GenericResultHandler)handler {
    NSURL *archiveURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
    [self makeArchive:archiveURL withHandler:^(NSURL *url) {
        if (url != nil) {
            UIViewController * vc = [AppDelegate getTopMostViewController];
            BOOL ok = [AppDelegate.instance openWithInteractionController:url withUTI:kHXOTransferArchiveUTI withName:kHXODefaultArchiveName inView:vc.view withController:vc removeFile:YES];
            handler(ok);
        } else {
            handler(NO);
        }
    }];
}

-(void) receiveArchive:(NSData*)archive onReady:(GenericResultHandler)handler {
    NSURL *archiveURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"received_archive.zip"];
    NSError * error;
    if ([archive writeToURL:archiveURL options:0 error:&error]) {
        [self importArchive:archiveURL withHandler:handler];
    } else {
        NSLog(@"receiveArchive: Failed to write archive to URL %@", archiveURL);
        handler(NO);
    }
}

- (void) receiveArchive:(NSURL*)launchURL {
    
    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        switch (buttonIndex) {
            case 0:
                // no
            {
                NSError *error = nil;
                [[NSFileManager defaultManager] removeItemAtURL:launchURL error:&error];
                if (error != nil) {
                    NSLog(@"#ERROR: failed to remove file %@, error=%@",launchURL, error);
                }
            }
                break;
            case 1: {
                NSData * archiveDat = [[UserProfile sharedProfile] receiveArchive:launchURL];
                [self.chatBackend disable];
                [self receiveArchive:archiveDat onReady:^(BOOL ok) {
                    if (ok) {
                        [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
                        [[UserProfile sharedProfile] verfierChangePlease];
                        [AppDelegate.instance showFatalErrorAlertWithMessage:NSLocalizedString(@"archive_imported_message", nil)
                                                                   withTitle:NSLocalizedString(@"archive_imported_title", nil)];
                        
                    } else {
                        [self.chatBackend enable];
                        [HXOUI showErrorAlertWithMessageAsync:@"archive_import_failed_message" withTitle:@"archive_import_failed_title"];
                        
                    }
                }];

            }
                break;
        }
        
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_import_alert_title", nil)
                                                    message: NSLocalizedString(@"archive_import_alert_message", nil)
                                            completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no", nil)
                                          otherButtonTitles:NSLocalizedString(@"archive_import_btn_title",nil),nil];
    [alert show];
}

- (void) receiveArchiveFile:(NSURL*)fileURL {
    
    [self.chatBackend disable];
    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        switch (buttonIndex) {
            case 0:
                // no
                [self.chatBackend enable];
                break;
            case 1: {
                [self importArchive:fileURL withHandler:^(BOOL ok) {
                    if (ok) {
                        [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
                        [[UserProfile sharedProfile] verfierChangePlease];
                        [AppDelegate.instance showFatalErrorAlertWithMessage:NSLocalizedString(@"archive_imported_message", nil)
                                                                   withTitle:NSLocalizedString(@"archive_imported_title", nil)];
                        
                    } else {
                        [self.chatBackend enable];
                        [HXOUI showErrorAlertWithMessageAsync:@"archive_import_failed_message" withTitle:@"archive_import_failed_title"];
                        
                    }
                }];
                
            }
                break;
        }
        
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_import_alert_title", nil)
                                                    message: NSLocalizedString(@"archive_import_alert_message", nil)
                                            completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no", nil)
                                          otherButtonTitles:NSLocalizedString(@"archive_import_btn_title",nil),nil];
    [alert show];
}

-(void) testFSSize {
    long long dataSize = [AppDelegate estimatedDocumentArchiveSize];
    NSLog(@"dirsize = %lld = %@", dataSize, [AppDelegate memoryFormatter:dataSize]);
    NSLog(@"free = %@", [AppDelegate memoryFormatter:[AppDelegate freeDiskSpace]]);
    NSLog(@"used = %@", [AppDelegate memoryFormatter:[AppDelegate usedDiskSpace]]);
    NSLog(@"total = %@", [AppDelegate memoryFormatter:[AppDelegate totalDiskSpace]]);
}

+ (NSString *)memoryFormatter:(long long)diskSpace {
    NSString *formatted;
    double bytes = 1.0 * diskSpace;
    double kilobytes = bytes / 1024;
    double megabytes = kilobytes / 1024;
    double gigabytes = megabytes / 1024;
    if (gigabytes >= 1.0)
        formatted = [NSString stringWithFormat:@"%.2f GB", gigabytes];
    else if (megabytes >= 1.0)
        formatted = [NSString stringWithFormat:@"%.2f MB", megabytes];
    else if (kilobytes >= 1.0)
        formatted = [NSString stringWithFormat:@"%.2f kB", kilobytes];
    else
        formatted = [NSString stringWithFormat:@"%.2f bytes", bytes];
    
    return formatted;
}

+ (long long)totalDiskSpace {
    long long space = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil] objectForKey:NSFileSystemSize] longLongValue];
    return space;
}

+ (long long)freeDiskSpace {
    long long freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil] objectForKey:NSFileSystemFreeSize] longLongValue];
    return freeSpace;
}

+ (long long)usedDiskSpace {
    long long usedSpace = [self totalDiskSpace] - [self freeDiskSpace];
    return usedSpace;
}

+ (long long)documentDirectorySizeIgnoring:(NSArray*)ignorePaths {
    
    NSNumber * totalSize = [AppDelegate sizeOfDirectoryAtURL:[AppDelegate.instance applicationDocumentsDirectory] ignoring:ignorePaths];

    return [totalSize longLongValue];
}

+ (long long)databaseFileSize {
    return [self sizeOfFileAtURL:[AppDelegate.instance persistentStoreURL]];
}

+ (long long)archiveFileSize {
    NSURL* archiveURL = [[AppDelegate.instance applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
    return [self sizeOfFileAtURL:archiveURL];
}

+ (long long)preferencesFileSize {
    NSURL *archivePrefURL = [[AppDelegate.instance applicationDocumentsDirectory] URLByAppendingPathComponent: @"archived.preferences"];
    return [self sizeOfFileAtURL:archivePrefURL];
}

// returns the approximate size to create an archive of all data; will slightly overestimate because it does not consider compression
+ (long long)estimatedDocumentArchiveSize {
    return [self documentDirectorySizeIgnoring:@[kHXODefaultArchiveName,@"Inbox"]] + [self databaseFileSize] + [self preferencesFileSize];
}

+ (NSNumber *) sizeOfFileAtURL: (NSURL *) fileURL withError: (NSError**) myError {
    if (myError != nil) {
        *myError = nil;
    }
    NSString * myPath = [fileURL path];
    NSNumber * result =  @([[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:myError] fileSize]);
    if (myError != nil && *myError != nil) {
        NSLog(@"WARNING: can not determine size of file '%@', error=%@", myPath, *myError);
        result = @(-1);
    }
    return result;
}

+ (long long) sizeOfFileAtURL: (NSURL *) fileURL {
    NSError * myError = nil;
    NSString * myPath = [fileURL path];
    NSNumber * result =  @([[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:&myError] fileSize]);
    if (myError != nil) {
        return 0;
    }
    return [result longLongValue];
}

+(NSNumber*)sizeOfDirectoryAtURL:(NSURL*)theDirectoryURL ignoring:(NSArray*)ignorePaths {
    if (TRACE_FILE_SEARCH) NSLog(@"sizeOfDirectoryAtURL: %@",theDirectoryURL);
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[theDirectoryURL path] isDirectory:&isDirectory];
    NSError * error = nil;
    if (exists) {
        if (!isDirectory) {
            NSLog(@"sizeOfDirectoryAtURL: file at path is not a directory:%@",[theDirectoryURL path]);
        } else {
            long long totalSize = 0;
            NSArray * subpaths = [[NSFileManager defaultManager] subpathsAtPath:[theDirectoryURL path]];
            for (NSString * subpath in subpaths) {
                NSString * fullPath = [[theDirectoryURL path] stringByAppendingPathComponent: subpath];
                NSURL * fullPathURL = [NSURL fileURLWithPath:fullPath];
                //NSLog(@"fullPath=%@",fullPath);
                
                BOOL ignore = NO;
                for (NSString * is in ignorePaths) {
                    if ([subpath rangeOfString:is].length == is.length) {
                        ignore = YES;
                    }
                }
                
                if (ignore) {
                    NSLog(@"Ignoring file: %@",subpath);
                } else {
                    NSNumber * fileSize = [self sizeOfFileAtURL:fullPathURL withError:&error];
                    if (error == nil) {
                        totalSize += [fileSize longLongValue];
                        if (TRACE_FILE_SEARCH) NSLog(@"Counting file: %@, size %@, total %lld",subpath, fileSize, totalSize);
                    } else {
                        NSLog(@"#ERROR: Failed to determine size of file %@, error=%@",fullPathURL,error);
                    }
                }
            }
            return @(totalSize);
        }
    } else {
        NSLog(@"sizeOfDirectoryAtURL: file at path does not exist:%@",[theDirectoryURL path]);
    }
    return @(-1);
}

+ (NSArray *)fileUrlsInDocumentDirPath:(NSString *)fileDirPath withExtension:(NSString *)fileExtension
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    if(fileDirPath.length > 0 && [fileDirPath hasPrefix:@"/"] == NO)
        path = [path stringByAppendingString:@"/"];
    
    path = [path stringByAppendingString:fileDirPath];
    
    NSError *error = nil;
    NSArray *pathContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    
    NSArray *sortedPathsContent = [pathContent sortedArrayUsingSelector: @selector(compare:)];
    
    NSMutableArray *resultArray = [NSMutableArray new];
    
    for (NSString *p in sortedPathsContent)
    {
        if(fileExtension && [p hasSuffix:fileExtension] == NO)
            continue;
        
        NSData *data = [NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:p]];
        
        if(data)
            [resultArray addObject:data];
    }
    
    return resultArray;
}

+ (NSDate*)modificationDateFromEtag:(NSString*)etag {
    NSRange startRange = [etag rangeOfString:@":M"];
    NSRange endRange = [etag rangeOfString:@"M:"];
    if (startRange.location != NSNotFound && endRange.location != NSNotFound) {
        NSRange modificationDateRange = NSMakeRange(startRange.location+startRange.length, endRange.location - startRange.location);
        NSString * timeString = [etag substringWithRange:modificationDateRange];
        if (timeString.length > 0) {
            unsigned long long time = [timeString longLongValue];
            NSDate * date = [NSDate dateWithTimeIntervalSince1970:time];
            return date;
        }
    }
    return nil;
}

+ (NSString *)etagFromAttributes:(NSDictionary*) attributes {
    
    if ([attributes objectForKey:NSFileModificationDate] &&
        [attributes objectForKey:NSFileCreationDate] &&
        [attributes objectForKey:NSFileSystemFileNumber]
        )
    {
        unsigned long fileSystemNumber = [attributes fileSystemFileNumber];
        unsigned long long created = [[attributes fileCreationDate] timeIntervalSince1970];
        unsigned long long lastMod = [[attributes fileModificationDate] timeIntervalSince1970];
        unsigned long permissions = [attributes filePosixPermissions];
        unsigned long long fileSize;
        NSString * etag;
        if ([attributes objectForKey:NSFileSize]) {
            fileSize= [attributes fileSize];
            etag = [NSString stringWithFormat:@"ev2:M%quM:P%#oP:F%luF:C%quC:S%quS",lastMod,(short)permissions,fileSystemNumber, created, fileSize];
        } else {
            etag = [NSString stringWithFormat:@"ev2:M%quM:P%#oP:F%luF:C%quC:d",lastMod,(short)permissions,fileSystemNumber, created];
        }
        // NSLog(@"return etag %@", etag);
        return etag;
    }
    return nil;
}

+(NSMutableDictionary*)entityIdsOfFiles:(NSArray*)fileNames inDirectory:(NSURL*)theDirectoryURL {
    NSMutableDictionary * result = [NSMutableDictionary new];
    for (NSString * fileName in fileNames) {
        NSString * fullPath = [[theDirectoryURL path] stringByAppendingPathComponent: fileName];
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
        NSString * etag = [self etagFromAttributes:attributes];
        if (etag != nil) {
            result[fileName] = etag;
        } else {
            NSLog(@"Could not get etag for file %@", fullPath);
        }
    }
    return result;
}

+(NSArray*)fileNamesInDirectoryAtURL:(NSURL*)theDirectoryURL ignorePaths:(NSArray*)ignorePaths ignoreSuffixes:(NSArray*)ignoreSuffixes {
    if (TRACE_FILE_SEARCH) NSLog(@"fileUrlsInDirectoryAtURL: %@",theDirectoryURL);
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[theDirectoryURL path] isDirectory:&isDirectory];
    NSError * error = nil;
    NSMutableArray * result = [NSMutableArray new];
    if (exists) {
        if (!isDirectory) {
            NSLog(@"sizeOfDirectoryAtURL: object at path is not a directory:%@",[theDirectoryURL path]);
        } else {
            //NSArray * subpaths = [[NSFileManager defaultManager] subpathsAtPath:[theDirectoryURL path]];
            NSArray * subpaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[theDirectoryURL path] error:&error];
            for (NSString * subpath in subpaths) {
                NSString * fullPath = [[theDirectoryURL path] stringByAppendingPathComponent: subpath];
                //NSURL * fullPathURL = [NSURL fileURLWithPath:fullPath];
                //NSLog(@"fullPath=%@",fullPath);
                
                BOOL ignore = NO;
                BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
                if (!exists) {
                    NSLog(@"#ERROR: file does not exist: %@",subpath);
                    ignore = YES;
                }
                if (isDirectory) {
                    ignore = YES;
                }
                
                for (NSString * is in ignoreSuffixes) {
                    if ([is isEqualToString:[subpath pathExtension]]) {
                        ignore = YES;
                        break;
                    }
                }
                
                for (NSString * is in ignorePaths) {
                    if ([subpath startsWith:is]) {
                        ignore = YES;
                        break;
                    }
                }
                
                if (ignore) {
                    if (TRACE_FILE_SEARCH) NSLog(@"Ignoring file: %@",subpath);
                } else {
                    if (TRACE_FILE_SEARCH) NSLog(@"Adding file: %@",subpath);
                    [result addObject:subpath];
                }
            }
            return result;
        }
    } else {
        NSLog(@"fileNamesInDirectoryAtURL: file at path does not exist:%@",[theDirectoryURL path]);
    }
    return nil;
}

+(BOOL)unzipFileAtURL:(NSURL*)zipFileURL toDirectory:(NSURL*) theDirectoryURL {
    NSLog(@"unzipFileAtURL: %@ -> %@",zipFileURL, theDirectoryURL);
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[theDirectoryURL path] isDirectory:&isDirectory];
    if (exists) {
        if (!isDirectory) {
            NSLog(@"zipDirectoryAtURL: file at path is not a directory:%@",[theDirectoryURL path]);
        } else {
            ZipArchive* zip = [[ZipArchive alloc] init];
            zip.progressBlock = ^(int percentage, int filesProcessed, unsigned long numFiles) {
                NSLog(@"Unzipped %d of %lu files (%d%%)", filesProcessed, numFiles, percentage);
            };
            if([zip UnzipOpenFile:[zipFileURL path]]) {
                NSLog(@"Zip File openend:%@",[zipFileURL path]);
                if ([zip UnzipFileTo:[theDirectoryURL path] overWrite:YES]) {
                    NSLog(@"Extracted %lu files from %@",(unsigned long)zip.unzippedFiles.count, [zipFileURL path]);
                    if (![zip UnzipCloseFile]) {
                        NSLog(@"#ERROR: failed to close zip file:%@",[zipFileURL path]);
                    } else {
                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}


+(BOOL)zipDirectoryAtURL:(NSURL*)theDirectoryURL toZipFile:(NSURL*)zipFileURL ignoring:(NSArray*)ignorePaths {
    NSLog(@"zipDirectoryAtURL: %@ -> %@",theDirectoryURL,zipFileURL);
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[theDirectoryURL path] isDirectory:&isDirectory];
    if (exists) {
        if (!isDirectory) {
            NSLog(@"zipDirectoryAtURL: file at path is not a directory:%@",[theDirectoryURL path]);
        } else {
            ZipArchive* zip = [[ZipArchive alloc] init];
            if([zip CreateZipFile2:[zipFileURL path]]) {
                NSLog(@"Zip File Created:%@",[zipFileURL path]);
                NSArray * subpaths = [[NSFileManager defaultManager] subpathsAtPath:[theDirectoryURL path]];
                for (NSString * subpath in subpaths) {
                    NSString * fullPath = [[theDirectoryURL path] stringByAppendingPathComponent: subpath];
                    //NSLog(@"fullPath=%@",fullPath);
                    
                    BOOL ignore = NO;
                    for (NSString * is in ignorePaths) {
                        if ([subpath rangeOfString:is].length == is.length) {
                            ignore = YES;
                        }
                    }
                    if ([fullPath isEqualToString:[zipFileURL path]]) {
                        ignore =YES;
                    }

                    if (ignore) {
                        NSLog(@"Ignoring archive file: %@",subpath);
                    } else {
                        NSLog(@"Adding to zip: %@",subpath);
                        if([zip addFileToZip:fullPath newname:subpath]) {
                            //NSLog(@"File '%@' Added to zip as '%@'",fullPath,subpath);
                        } else {
                            NSLog(@"#ERROR: Failed to add file '%@' Added to zip as '%@'",fullPath,subpath);
                        }
                    }
                }
                if ([zip CloseZipFile2]) {
                    return YES;
                } else {
                    NSLog(@"#ERROR: Failed to close zip file '%@'",[zipFileURL path]);
                }
            } else {
                NSLog(@"#ERROR: Failed to open zip file '%@'",[zipFileURL path]);
            }
        }
    } else {
        NSLog(@"zipDirectoryAtURL: file at path does not exist:%@",[theDirectoryURL path]);
    }
    return NO;
}

- (void) makeArchive:(NSURL*)archiveURL withHandler:(URLResultHandler)onReady {
    ModalTaskHUD * hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"archive_make_hud_title", nil)];
    [hud show];
    [self pauseDocumentMonitoring];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSURL * url = [self makeArchive:archiveURL];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            onReady(url);
            [self resumeDocumentMonitoring];
        });
    });
}

- (NSURL*)makeArchive:(NSURL*)archiveURL {
    NSError *error = nil;
    
    {
        //NSURL *deleteURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"default.archive"];
        //[[NSFileManager defaultManager] removeItemAtURL:deleteURL error:&error];
        
        NSURL *archivedbURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"archived.database"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[archivedbURL path]]) {
            [[NSFileManager defaultManager] removeItemAtURL:archivedbURL error:&error];
            if (error != nil) {
                NSLog(@"Error removing old database archive at URL %@, error=%@", archivedbURL, error);
                return nil;
            } else {
                NSLog(@"Removed old database archive at URL %@", archivedbURL);
            }
        }
        NSURL *dbURL = [self persistentStoreURL];
        [[NSFileManager defaultManager] copyItemAtURL:dbURL toURL:archivedbURL error:&error];
        if (error != nil) {
            NSLog(@"Error copying database from %@ to %@, error=%@", dbURL, archivedbURL, error);
            return nil;
        } else {
            NSLog(@"Copied database from %@ to %@", dbURL, archivedbURL);
        }
    }
    
    {
        NSURL *archivePrefURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"archived.preferences"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[archivePrefURL path]]) {
            [[NSFileManager defaultManager] removeItemAtURL:archivePrefURL error:&error];
            if (error != nil) {
                NSLog(@"Error removing old preferences archive at URL %@, error=%@", archivePrefURL, error);
                return nil;
            } else {
                NSLog(@"Removed old database archive at URL %@", archivePrefURL);
            }
        }
        NSURL *prefURL = [self preferencesURL];
        [[HXOUserDefaults standardUserDefaults] synchronize];
        [[NSFileManager defaultManager] copyItemAtURL:prefURL toURL:archivePrefURL error:&error];
        if (error != nil) {
            NSLog(@"Error copying database from %@ to %@, error=%@", prefURL, archivePrefURL, error);
            return nil;
        } else {
            NSLog(@"Copied database from %@ to %@", prefURL, archivePrefURL);
        }
    }
    
    [UserProfile.sharedProfile exportCredentialsWithPassphrase:@"iafnf&/512%2773=!)/%JJNS&&/()JNjnwn"];
    
    //NSURL *archiveURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"archive.zip"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[archiveURL path]]) {
        [[NSFileManager defaultManager] removeItemAtURL:archiveURL error:&error];
        if (error != nil) {
            NSLog(@"Error removing old archive at URL %@, error=%@", archiveURL, error);
        } else {
            NSLog(@"Removed old archive at URL %@", archiveURL);
        }
    }

    // zip it
    if (error == nil) {
        if (![AppDelegate zipDirectoryAtURL:[self applicationDocumentsDirectory] toZipFile:archiveURL ignoring:@[@"Inbox"]]) {
            NSLog(@"Failed to create archive at URL %@", archiveURL);
            [[NSFileManager defaultManager] removeItemAtURL:archiveURL error:&error];
            return nil;
        }
    }
    
    // cleanup
    NSURL *archivedbURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"archived.database"];
    [[NSFileManager defaultManager] removeItemAtURL:archivedbURL error:&error];
    if (error != nil) {
        NSLog(@"Error removing temporary database archive at URL %@, error=%@", archivedbURL, error);
    } else {
        NSLog(@"Removed temporary database archive at URL %@", archivedbURL);
    }
    
    NSURL *archivePrefURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"archived.preferences"];
    [[NSFileManager defaultManager] removeItemAtURL:archivePrefURL error:&error];
    if (error != nil) {
        NSLog(@"Error removing temporary preferences archive at URL %@, error=%@", archivePrefURL, error);
    } else {
        NSLog(@"Removed temporary database archive at URL %@", archivePrefURL);
    }
    
    [[UserProfile sharedProfile] deleteCredentialsFile];
    
    return archiveURL;
}

enum {
    ARCHIVE_INSTALLED_CREDENTIALS_OLD = 0,
    ARCHIVE_INSTALLED_CREDENTIALS_IDENTICAL = 1,
    ARCHIVE_INSTALLED_CREDENTIALS_NEW = 2,
    ARCHIVE_INSTALLED_CREDENTIALS_BROKEN = -80,
    ARCHIVE_NOT_INSTALLED_CANT_MOVE_FILE = -70,
    ARCHIVE_NOT_INSTALLED_ARCHIVE_DIR_ERROR = -60,
    ARCHIVE_NOT_INSTALLED_CANT_REMOVE_FILE = -50,
    ARCHIVE_NOT_INSTALLED_DOCUMENT_DIR_ERROR = -40,
    ARCHIVE_NOT_INSTALLED_PREFERENCE_ERROR = -35,
    ARCHIVE_NOT_INSTALLED_NEW_DATABASE_MOVE_ERROR = -30,
    ARCHIVE_NOT_INSTALLED_OLD_DATABASE_MOVE_ERROR = -20,
    ARCHIVE_NOT_INSTALLED_OLD_DB_BACKUP_REMOVE_ERROR = -10,
    ARCHIVE_NOT_INSTALLED_NO_NEW_DATABASE_ERROR = -5,
    ARCHIVE_NOT_INSTALLED_ERROR_NO_ARCHIVE_TO_INSTALL = -1
};

- (void) importArchive:(NSURL*)archiveURL withHandler:(GenericResultHandler)onReady {
    ModalTaskHUD * hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"archive_import_hud_title", nil)];
    [hud show];
    [self pauseDocumentMonitoring];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        BOOL success = [self extractArchive:archiveURL];
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.title = NSLocalizedString(@"archive_install_hud_title", nil);
            });
            int result = [self installArchive];
            if (result < 0) {
                // total failure
                success = NO;
            } else {
                if (result == ARCHIVE_INSTALLED_CREDENTIALS_IDENTICAL || result == ARCHIVE_INSTALLED_CREDENTIALS_NEW) {
                    // total success
                    success = YES;
                } else {
                    if (result == ARCHIVE_INSTALLED_CREDENTIALS_OLD) {
                        [hud dismiss];
                        // credentials import failed
                        [self showOperationFailedAlert:@"credentials_receive_old_message" withTitle:@"credentials_receive_old_title"
                                           withOKBlock:^{
                                               onReady(YES);
                                           }];
                        return;
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            onReady(success);
            if (!success) {
                [self resumeDocumentMonitoring];
            }
        });
    });
}


- (BOOL)extractArchive:(NSURL*) archiveURL {
    NSError *error = nil;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    if (![fileMgr fileExistsAtPath:[archiveURL path]]) {
        NSLog(@"Error: No archive at URL %@", archiveURL);
    } else {
        NSURL *archiveExtractDirURL = [[self applicationLibraryDirectory] URLByAppendingPathComponent: @"unarchived"];
        
        if ([fileMgr fileExistsAtPath:[archiveExtractDirURL path]]) {
            NSLog(@"Removing archive extraction directory at URL %@", archiveExtractDirURL);
            [fileMgr removeItemAtURL:archiveExtractDirURL error:&error];
            if (error != nil) {
                NSLog(@"Error removing old unarchived dir at URL %@, error=%@", archiveExtractDirURL, error);
                return NO;
            } else {
                NSLog(@"Removed old archive extraction directory at URL %@", archiveExtractDirURL);
            }
            
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:[archiveExtractDirURL path] withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (error != nil) {
            NSLog(@"Error creating archive extraction directory at URL %@, error=%@", archiveExtractDirURL, error);
        } else {
            NSLog(@"Created archive extraction directory at URL %@", archiveExtractDirURL);
            if ([AppDelegate unzipFileAtURL:archiveURL toDirectory:archiveExtractDirURL]) {
                [fileMgr removeItemAtURL:archiveURL error:&error];
                if (error != nil) {
                    NSLog(@"Error removing extracted archive at URL %@, error=%@", archiveURL, error);
                    return NO;
                } else {
                    NSLog(@"Removed extracted archive at URL %@", archiveURL);
                }
                
                // all files extracted
                return YES;
            }
        }
    }
    return NO;
}


-(int)installArchive {
    [self.chatBackend disable];
    NSError *error = nil;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSURL *archiveExtractDirURL = [[self applicationLibraryDirectory] URLByAppendingPathComponent: @"unarchived"];
    
    BOOL isDirectory;
    BOOL exists = [fileMgr fileExistsAtPath:[archiveExtractDirURL path] isDirectory:&isDirectory];
    if (exists) {
        if (!isDirectory) {
        } else {
            NSURL *dbURL = [self persistentStoreURL];
            // NSString * dbName = [dbURL lastPathComponent];
            NSURL *archivedbURL = [archiveExtractDirURL URLByAppendingPathComponent: @"archived.database"];
            NSURL *backupdbURL = [archiveExtractDirURL URLByAppendingPathComponent: @"backupdb.sqlite"];
            if (![fileMgr fileExistsAtPath:[archivedbURL path]]) {
                NSLog(@"#ERROR: no database to install found at archive URL %@", backupdbURL);
                return ARCHIVE_NOT_INSTALLED_NO_NEW_DATABASE_ERROR;
            } else {
                if ([fileMgr fileExistsAtPath:[backupdbURL path]]) {
                    // remove old backup if necessary
                    [fileMgr removeItemAtURL:backupdbURL error:&error];
                    if (error != nil) {
                        NSLog(@"Error removing old database backup at URL %@, error=%@", backupdbURL, error);
                        return ARCHIVE_NOT_INSTALLED_OLD_DB_BACKUP_REMOVE_ERROR;
                    } else {
                        NSLog(@"Removed old database backup at URL %@", backupdbURL);
                    }
                }
                // move current db to backup
                [fileMgr moveItemAtURL:dbURL toURL:backupdbURL error:&error];
                if (error != nil) {
                    NSLog(@"Error moving old database from %@ to backup URL %@, error=%@", dbURL, backupdbURL, error);
                    return ARCHIVE_NOT_INSTALLED_OLD_DATABASE_MOVE_ERROR;
                } else {
                    NSLog(@"Moved old database from %@ to backup at URL %@", dbURL, backupdbURL);
                }
                
                // move archive db to current
                [fileMgr moveItemAtURL:archivedbURL toURL:dbURL error:&error];
                if (error != nil) {
                    NSLog(@"Error moving archived database from %@ to current URL %@, error=%@", archivedbURL, dbURL, error);
                    // move database backup back in place
                    [fileMgr moveItemAtURL:backupdbURL toURL:dbURL error:&error];
                    if (error != nil) {
                        NSLog(@"Error moving back archived database from %@ to current URL %@, error=%@", backupdbURL, dbURL, error);
                    }
                    return ARCHIVE_NOT_INSTALLED_NEW_DATABASE_MOVE_ERROR;
                } else {
                    NSLog(@"Moved archive database from %@ to current at URL %@", archivedbURL, dbURL);
                }
                
                //NSURL *prefURL = [self preferencesURL];
                NSURL *archivePrefURL = [archiveExtractDirURL URLByAppendingPathComponent: @"archived.preferences"];
                NSURL *backupPrefURL = [archiveExtractDirURL URLByAppendingPathComponent: @"backuped.preferences"];
                if (![fileMgr fileExistsAtPath:[archivePrefURL path]]) {
                    NSLog(@"#ERROR: no preferences to install found at archive URL %@", backupPrefURL);
                    return ARCHIVE_NOT_INSTALLED_PREFERENCE_ERROR;
                } else {
                    NSDictionary * defaults = [NSDictionary dictionaryWithContentsOfURL:archivePrefURL];
                    [defaults enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
                        NSLog(@"Setting prefence %@ to %@", key, object);
                        [[HXOUserDefaults standardUserDefaults] setObject:object forKey:key];
                    }];
                    [[HXOUserDefaults standardUserDefaults] synchronize];
                    
                    // clear document directory first
                    NSURL * docDir = [self applicationDocumentsDirectory];
                    {
                        NSArray *fileArray = [fileMgr contentsOfDirectoryAtURL:docDir includingPropertiesForKeys:@[] options:0 error:&error];
                        if (error != nil) {
                            NSLog(@"Error gettting content of document directory %@, error=%@", docDir, error);
                            return ARCHIVE_NOT_INSTALLED_DOCUMENT_DIR_ERROR;
                        }
                        NSURL * inbox = [docDir URLByAppendingPathComponent:@"Inbox"];
                        NSString * inboxPath = [inbox path];
                        for (NSURL * fileToRemove in fileArray)  {
                            
                            NSString * path = [fileToRemove path];
                            NSLog(@"  path = %@", path);
                            NSLog(@"ibpath = %@", inboxPath);
                            NSRange inInbox = [path rangeOfString:inboxPath];
                            NSLog(@"range: location %lu len %lu", (unsigned long)inInbox.location, (unsigned long)inInbox.length);
                            
                            if (inInbox.location == NSNotFound) {
                                
                                [fileMgr removeItemAtURL:fileToRemove error:&error];
                                if (error != nil) {
                                    NSLog(@"Error removing file %@, error=%@", fileToRemove, error);
                                    return ARCHIVE_NOT_INSTALLED_CANT_REMOVE_FILE;
                                } else {
                                    NSLog(@"Removed file %@", fileToRemove);
                                }
                            } else {
                                NSLog(@"Ignoring inbox file %@", fileToRemove);
                            }
                        }
                    }
                    
                    // move all the files to document directory
                    NSArray *fileArray = [fileMgr contentsOfDirectoryAtURL:archiveExtractDirURL includingPropertiesForKeys:@[] options:0 error:&error];
                    if (error != nil) {
                        NSLog(@"Error gettting content of document directory %@, error=%@", docDir, error);
                        return ARCHIVE_NOT_INSTALLED_ARCHIVE_DIR_ERROR;
                    }
                    for (NSURL * fileToMove in fileArray)  {
                        NSURL * destURL = [docDir URLByAppendingPathComponent:[fileToMove lastPathComponent]];
                        [fileMgr moveItemAtURL:fileToMove toURL:destURL error:&error];
                        if (error != nil) {
                            NSLog(@"Error moving file %@ to %@, error=%@", fileToMove, destURL, error);
                            return ARCHIVE_NOT_INSTALLED_CANT_MOVE_FILE;
                        } else {
                            NSLog(@"Moved file %@ to %@", fileToMove, destURL);
                        }
                    }
                    
                    // get the credentials now
                    int result = [UserProfile.sharedProfile importCredentialsWithPassphrase:@"iafnf&/512%2773=!)/%JJNS&&/()JNjnwn" withForce:NO];
                    if (result == CREDENTIALS_OLDER) {
                        return ARCHIVE_INSTALLED_CREDENTIALS_OLD;
                    }
                    if (result == CREDENTIALS_IMPORTED) {
                        return ARCHIVE_INSTALLED_CREDENTIALS_NEW;
                    }
                    if (result == CREDENTIALS_IDENTICAL) {
                        return ARCHIVE_INSTALLED_CREDENTIALS_IDENTICAL;
                    }
                    return ARCHIVE_INSTALLED_CREDENTIALS_BROKEN;
                    // CREDENTIALS_BROKEN
                }
            }
        }
    }
    return ARCHIVE_NOT_INSTALLED_ERROR_NO_ARCHIVE_TO_INSTALL;
}

+ (BOOL) handleAsDataUTI:(NSString*)uti {
    NSArray * dataUTIs = @[@"com.adobe.photoshop-image",
                           @"com.adobe.illustrator.ai-image",
                           @"com.microsoft.windows-media-wmv",
                           @"com.microsoft.windows-media-wmp",
                           @"com.microsoft.windows-media-wma",
                           @"com.microsoft.windows-media-wmx",
                           @"com.microsoft.windows-media-wvx",
                           @"com.microsoft.windows-media-wax",
                           @"com.truevision.tga-image",
                           @"com.ilm.openexr-image",
                           @"com.kodak.flashpix.image",
                           @"com.digidesign.sd2-audio",
                           @"com.real.realmedia",
                           @"com.real.realaudio"
                           ];
    
    if ([dataUTIs containsObject:uti]) {
        return YES;
    }
    
    return NO;
}


// TODO: deal with mediatype text
+ (NSString*)mediaTypeOfUTI:(NSString*)documentType withFileName:(NSString*)filename{
    NSString * mediaType = nil;
    
    if (![self handleAsDataUTI:documentType]) {
        
        if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeText)) {
            mediaType=@"text";
        } else if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeImage)) {
            mediaType=@"image";
        } else if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeMovie)) {
            mediaType=@"video";
        } else if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeVideo)) {
            mediaType=@"video";
        } else if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeAudio)) {
            mediaType=@"audio";
        } else if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeVCard)) {
            mediaType=@"vcard";
        } else if (UTTypeConformsTo((__bridge CFStringRef)(documentType),kUTTypeURL)) {
            mediaType=@"text";
        }
    }
    if (mediaType == nil) {
        mediaType=@"data";
    }
    
    if (filename != nil) {
        if (([filename endsWith:@".json"] && [filename startsWith:@"location"]) || [filename endsWith:@".hcrgeo"]) {
            mediaType = @"geolocation";
        }
    }
    
    if ([mediaType isEqualToString:@"text"]) {
        mediaType=@"data";
    }
    return mediaType;
}


- (BOOL)handleFileURL: (NSURL *)url withDocumentType:(NSString*)documentType
{
    // handle backup archive
    //BOOL equal = UTTypeEqual((__bridge CFStringRef)(kHXOTransferArchiveUTI), (__bridge CFStringRef)(documentType));
    BOOL conforming = UTTypeEqual((__bridge CFStringRef)(documentType), (__bridge CFStringRef)(kHXOTransferArchiveUTI));
    
    if (conforming) {
        [self receiveArchiveFile:url];
        return YES;
    }
    
    // handle other stuff
    NSString *fileName = [url lastPathComponent];
    NSURL *destURL = [AppDelegate uniqueNewFileURLForFileLike:fileName isTemporary:YES];
    NSError *error = nil;
    
    NSString * mimeType = nil;
    NSString * mediaType = nil;

    NSLog(@"url=%@", url);
    NSLog(@"documentType in=%@", documentType);

    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
    if (exists) {
        if (!isDirectory) {
            [[NSFileManager defaultManager] copyItemAtURL:url toURL:destURL error:&error];
        } else {
            // When inbox item is a directory, zip it into a file
            NSString * urlpath = [destURL path];
            NSString * zippath = [urlpath stringByAppendingString:@".zip"];
            NSURL *zipfile = [NSURL fileURLWithPath:zippath];
            if ([AppDelegate zipDirectoryAtURL:url toZipFile:zipfile ignoring:@[]]) {
                destURL = zipfile;
                documentType = @"public.zip-archive";
                mimeType = @"application/zip";
                mediaType = @"data";
            } else {
                return NO;
            }
        }
    } else {
        NSLog(@"handleFileURL: file at path does not exist:%@",[url path]);
    }
    
    NSLog(@"documentType=%@", documentType);
    NSLog(@"destURL=%@", destURL);

    if (mediaType == nil) {
        mediaType = [AppDelegate mediaTypeOfUTI:documentType withFileName:fileName];
    }
    NSLog(@"mediaType=%@", mediaType);

    if (mimeType == nil) {
        mimeType = [Attachment mimeTypeFromUTI:documentType];
        if (error != nil) {
            NSLog(@"handleFileURL error %@", error);
            return NO;
        }
    }
    NSLog(@"mimeType=%@", mimeType);
    
    self.openedFileURL = destURL;
    self.openedFileDocumentType = documentType;
    self.openedFileMediaType = mediaType;
    self.openedFileMimeType = mimeType;
    self.openedFileName = [destURL lastPathComponent];
    
    return YES;
}

- (void) didPairWithStatus: (BOOL) success { // pregnant...
    [self showPairingAlert: success];
}

- (void) showPairingAlert: (BOOL) success {
    NSString * title;
    NSString * message;
    if (success) {
        return;
        // title = NSLocalizedString(@"Invite successful", @"Invite Alert Title");
        // message = NSLocalizedString(@"The server accepted your code", @"Invite Alert Message");
    } else {
        title = NSLocalizedString(@"invite_error_alert_title", @"Invite Alert Title");
        message = NSLocalizedString(@"invite_error_rejected_by_server", @"Invite Alert Message");
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"ok",nil)
                                          otherButtonTitles:nil];

    [alert show];
}


- (void) showFatalErrorAlertWithMessage:  (NSString *) message withTitle:(NSString *) title {
    if (title == nil) {
        title = NSLocalizedString(@"fatal_error_default_title", nil);
    }
    if (message == nil) {
        message = HXOLocalizedString(@"fatal_error_default_message", @"Error Alert Message", HXOAppName(), HXOAppName());
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   completionBlock: ^(NSUInteger buttonIndex,UIAlertView* alertView) { exit(1); }
                                          cancelButtonTitle:NSLocalizedString(@"ok",nil)
                                          otherButtonTitles:nil];
    [alert show];
}

- (void) showGenericAlertWithTitle:(NSString *)title andMessage:(NSString *)message withOKBlock:(ContinueBlock)okBlock {
     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(title,nil)
                                                     message:NSLocalizedString(message,nil)
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView* alertView) { if (okBlock) okBlock(); }
                                           cancelButtonTitle:NSLocalizedString(@"ok",nil)
                                           otherButtonTitles:nil];
    [alert show];
}



- (void) showOperationFailedAlert:  (NSString *) message withTitle:(NSString *) title withOKBlock:(ContinueBlock)okBlock{
    if (title == nil) {
        title = NSLocalizedString(@"operation_failed_default_title", nil);
    }
    if (message == nil) {
        message = NSLocalizedString(@"operation_failed_default_message", nil);
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                            completionBlock: ^(NSUInteger buttonIndex,UIAlertView* alertView) { okBlock(); }
                                          cancelButtonTitle:NSLocalizedString(@"ok",nil)
                                          otherButtonTitles:nil];
    [alert show];
}


- (void) showCorruptedDatabaseAlert {
    [self showDeleteDatabaseAlertWithMessage:@"The database is corrupted. Your database must be deleted to continue. All chats will be deleted. Do you want to delete your database?" withTitle:@"Database corrupted"];
    
}

- (void) showDeleteDatabaseAlertWithMessage:  (NSString *) message withTitle:(NSString *) title {

    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        NSString * title_tag;
        NSString * message_tag;
        switch (buttonIndex) {
            case 0:
                title_tag = @"database_corrupt_not_deleted_title";
                message_tag = @"database_corrupt_not_deleted_message";
                break;
            case 1:
                [self deleteDatabase];
                title_tag = @"database_corrupt_deleted_title";
                message_tag = @"database_corrupt_deleted_message";
                break;
        }
        [self showFatalErrorAlertWithMessage: HXOLocalizedString(message_tag, nil, HXOAppName()) withTitle: NSLocalizedString(title_tag, nil)];

    };

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no", nil)
                                          otherButtonTitles:NSLocalizedString(@"database_delete_btn_title",nil),nil];
    [alert show];
}

- (void) showInvalidCredentialsWithInfo:(NSString*)info withContinueHandler:(ContinueBlock)onNotDeleted {
    
    
    HXOAlertViewCompletionBlock deleteCompletionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        switch (buttonIndex) {
            case 1: {
                NSString * title_tag;
                NSString * message_tag;
                [[UserProfile sharedProfile] deleteCredentials];
                [self deleteDatabase];
                title_tag = @"credentials_and_database_deleted_title";
                message_tag = @"credentials_and_database_deleted_message";
                [self showFatalErrorAlertWithMessage: NSLocalizedString(message_tag, nil) withTitle: NSLocalizedString(title_tag, nil)];
            }
        }
    };
    
    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        NSString * title_tag;
        NSString * message_tag;
        switch (buttonIndex) {
            case 0:
            {
                if (![info isEqualToString:@"Client deleted"]) {
                    title_tag = @"credentials_and_database_not_deleted_title";
                    message_tag = @"credentials_and_database_not_deleted_message";
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(title_tag,nil)
                                                                    message: NSLocalizedString(message_tag,nil)
                                                            completionBlock: onNotDeleted
                                                          cancelButtonTitle: NSLocalizedString(@"continue",nil)
                                                          otherButtonTitles:nil];
                    [alert show];
                }
            }
            break;
            case 1:
            {
                title_tag = @"credentials_and_database_really_delete_title";
                message_tag = nil;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(title_tag,nil)
                                                                message: NSLocalizedString(message_tag,nil)
                                                        completionBlock: deleteCompletionBlock
                                                      cancelButtonTitle:NSLocalizedString(@"no",nil)
                                                      otherButtonTitles:NSLocalizedString(@"credentials_database_delete_btn_title",nil),nil];
                [alert show];
            }
        }
        
    };
    
    NSString * message = nil;
    NSString * title = nil;
    if ([info isEqualToString:@"Verification failed"]) {
        message = [NSString stringWithFormat:NSLocalizedString(@"credentials_invalid_changed_delete_question", nil),info];
        title = NSLocalizedString(@"credentials_invalid_title", nil);
    } else if ([info isEqualToString:@"Client deleted"]) {
        message = [NSString stringWithFormat:NSLocalizedString(@"credentials_invalid_account_deleted_question", nil),info];
        title = NSLocalizedString(@"credentials_deleted_title", nil);
    } else {
        message = [NSString stringWithFormat:NSLocalizedString(@"credentials_invalid_delete_question", nil),info];
        title = NSLocalizedString(@"credentials_invalid_title", nil);
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                            completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no",nil)
                                          otherButtonTitles:NSLocalizedString(@"credentials_database_delete_btn_title",nil),nil];
    [alert show];
}


- (void) showLoginFailedWithInfo:(NSString*)info withContinueHandler:(ContinueBlock)onContinue {
    
    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        switch (buttonIndex) {
            case 0:
                // continue
                onContinue();
                break;
            case 1:
                // abort
                exit(0);
                break;
        }
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"backend_login_temporarily_failed_title", nil)
                                                    message: [NSString stringWithFormat:NSLocalizedString(@"backend_login_temporarily_failed_continue_question", nil),info]
                                            completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"continue",nil)
                                          otherButtonTitles:NSLocalizedString(@"abort",nil),nil];
    [alert show];
}

-(void) dumpAllRecordsOfEntityNamed:(NSString *)theEntityName {
    NSEntityDescription *entity = [NSEntityDescription entityForName:theEntityName inManagedObjectContext:self.mainObjectContext];
    NSFetchRequest *request = [NSFetchRequest new];
    [request setEntity:entity];
    NSError *error;
    NSMutableArray *fetchResults = [[self.mainObjectContext executeFetchRequest:request error:&error] mutableCopy];
    int i = 0;
    for (NSManagedObject * object in fetchResults) {
        NSLog(@"================== Showing object %d of entity '%@' =================", i, theEntityName);
        NSLog(@"================== id = %@",object.objectID);
        for (NSAttributeDescription * property in entity) {
            // NSLog(@"property '%@'", property.name);
            NSString * description = [[object valueForKey:property.name] description];
            if (description.length > 256) {
                description = [NSString stringWithFormat:@"%@...(%@ chars not shown)", [description substringToIndex:255], @(description.length - 256)];
            }
            NSLog(@"property '%@' = %@", property.name, description);
        }
        ++i;
    }
}

#pragma mark - Hoccer Talk Delegate


- (NSString*) apnDeviceToken {
    return [[HXOUserDefaults standardUserDefaults] stringForKey: kHXOAPNDeviceToken];
}

- (void) backendDidStop {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        [self saveDatabaseNow];
        [self setLastActiveDate];
        NSLog(@"#INFO: backendDidStop: done with background task ... good night");
        [[UIApplication sharedApplication] endBackgroundTask: _backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
}

-(void) didFailWithInvalidCertificate:(DoneBlock)done {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"certificate_invalid_title", nil)
                                                     message: HXOLocalizedString(@"certificate_invalid_message", nil, HXOAppName())
                                             completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alertView) { done(); }
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

+ (void) updateStatusbarForViewController:(UIViewController*)viewcontroller style:(UIStatusBarStyle)theStyle {
    // NSLog(@"updateStatusbar");
    
    [UIView animateWithDuration:0.5
     
                          delay: 0.0
     
                        options: UIViewAnimationOptionTransitionNone
     
                     animations:^{
                         //UIApplication.sharedApplication.statusBarStyle = UIStatusBarStyleDefault; // black font
                         //UIApplication.sharedApplication.statusBarStyle = UIStatusBarStyleLightContent; // white font
                         UIApplication.sharedApplication.statusBarStyle = theStyle;
                     }
     
                     completion:^(BOOL finished){
                         // NSLog(@"statusBarStyle animation done");
                     }];
    if ([viewcontroller respondsToSelector:(@selector(setNeedsStatusBarAppearanceUpdate))]) {
        [viewcontroller setNeedsStatusBarAppearanceUpdate];
    }
    // NSLog(@"setNeedsStatusBarAppearanceUpdate");
}

+ (void) setBlackFontStatusbarForViewController:(UIViewController*)viewcontroller {
    [AppDelegate updateStatusbarForViewController:viewcontroller style:UIStatusBarStyleDefault];
}

+ (void) setWhiteFontStatusbarForViewController:(UIViewController*)viewcontroller {
    [AppDelegate updateStatusbarForViewController:viewcontroller style:UIStatusBarStyleLightContent];
}

//TODO: maybe remove strange UNICODE chars as well
+ (NSString *)sanitizeFileNameString:(NSString *)fileName {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    return [[fileName componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@"_"];
}

+ (NSString *)uniqueFilenameForFilename: (NSString *)theFilename inDirectory: (NSString *)directory {
    
	if (![[NSFileManager defaultManager] fileExistsAtPath: [directory stringByAppendingPathComponent:theFilename]]) {
		return theFilename;
	};
	
	NSString *ext = [theFilename pathExtension];
	NSString *baseFilename = [theFilename stringByDeletingPathExtension];
	
	NSInteger i = 1;
	NSString* newFilename = [NSString stringWithFormat:@"%@_%@", baseFilename, [@(i) stringValue]];
    
    if ((ext == nil) || (ext.length <= 0)) {
        ext = @"";
        //NSLog(@"empty ext 3");
    }
	newFilename = [newFilename stringByAppendingPathExtension: ext];
	while ([[NSFileManager defaultManager] fileExistsAtPath: [directory stringByAppendingPathComponent:newFilename]]) {
		newFilename = [NSString stringWithFormat:@"%@_%@", baseFilename, [@(i) stringValue]];
		newFilename = [newFilename stringByAppendingPathExtension: ext];
		i++;
	}
	return newFilename;
}

+ (NSURL *)uniqueNewFileURLForFileLike:(NSString *)fileNameHint isTemporary:(BOOL)temporary {
    
    NSString *newFileName = [AppDelegate sanitizeFileNameString: fileNameHint];
    NSURL * appDocDir;
    if (temporary) {
        appDocDir = AppDelegate.instance.applicationTemporaryDocumentsDirectory;
    } else {
        appDocDir = AppDelegate.instance.applicationDocumentsDirectory;
    }
    NSString * myDocDir = [appDocDir path];
    NSString * myUniqueNewFile = [[self class]uniqueFilenameForFilename: newFileName inDirectory: myDocDir];
    NSString * savePath = [myDocDir stringByAppendingPathComponent: myUniqueNewFile];
    NSURL * myLocalURL = [NSURL fileURLWithPath:savePath];
    return myLocalURL;
}

+ (NSURL *)moveDocumentToPermanentLocation:(NSURL*)temporaryFile {
    
    NSString * fileNameHint = [temporaryFile lastPathComponent];
    NSURL * permanentURL = [self uniqueNewFileURLForFileLike:fileNameHint isTemporary:NO];
    NSError * error = nil;
    [[NSFileManager defaultManager] moveItemAtURL:temporaryFile toURL:permanentURL error:&error];
    if (error != nil) {
        NSLog(@"#ERROR moving temporary file from %@ to permanent location %@", temporaryFile, permanentURL);
    } else {
        NSLog(@"Moved temporary file from %@ to permanent location %@", temporaryFile, permanentURL);

    }
    return permanentURL;
}

@synthesize peoplePicker = _peoplePicker;
- (ABPeoplePickerNavigationController*) peoplePicker {
    if ( ! _peoplePicker) {
        _peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
    }
    return _peoplePicker;
}

+ (AppDelegate*)instance {
    return gAppDelegate;
    /*
    return (AppDelegate*)[[UIApplication sharedApplication] delegate];
     */
}

+ (BOOL)validateString:(NSString *)string withPattern:(NSString *)pattern
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    
    NSAssert(regex, @"Unable to create regular expression");
    
    NSRange textRange = NSMakeRange(0, string.length);
    NSRange matchRange = [regex rangeOfFirstMatchInString:string options:NSMatchingReportProgress range:textRange];
    
    BOOL didValidate = NO;
    
    // Did we find a matching range
    if (matchRange.location != NSNotFound)
        didValidate = YES;
    
    return didValidate;
}

+ (void) renewRSAKeyPairWithSize: (NSUInteger) size {
    ModalTaskHUD * hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"key_renewal_hud_title", nil)];
    [hud show];
    [UserProfile.sharedProfile renewKeypairWithSize: size completion: ^(BOOL success){
        [hud dismiss];
        id userInfo = @{ @"itemsChanged":@{@"publicKey": @YES}};
        if (TRACE_PROFILE_UPDATES) NSLog(@"profileUpdatedByUser info %@",userInfo);
        NSNotification *notification = [NSNotification notificationWithName:@"profileUpdatedByUser" object:self userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }];
}

-(HTTPServerController*)httpServer {
    if (_httpServer == nil) {
        _httpServer = [[HTTPServerController alloc] initWithDocumentRoot: [self.applicationDocumentsDirectory path]];
    }
    return _httpServer;
}

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

- (NSString *)ownIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;

    NSDictionary *addresses = [self ownIPAddresses];
    //NSLog(@"addresses: %@", addresses);

    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

- (NSDictionary *)ownIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];

    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) || (interface->ifa_flags & IFF_LOOPBACK)) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                char addrBuf[INET6_ADDRSTRLEN];
                if(inet_ntop(addr->sin_family, &addr->sin_addr, addrBuf, sizeof(addrBuf))) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, addr->sin_family == AF_INET ? IP_ADDR_IPv4 : IP_ADDR_IPv6];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

#pragma mark - Remote control event handling

- (void) remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        HXOAudioPlayer *player = [HXOAudioPlayer sharedInstance];

        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPause:
                [player pause];
                break;

            case UIEventSubtypeRemoteControlPlay:
                [player play];
                break;
                
            case UIEventSubtypeRemoteControlTogglePlayPause:
                [player togglePlayPause];
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:
                [player skipBack];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
                [player skipForward];
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - TabBarControllerDelegate

- (void) tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    UIViewController *destinationViewController = viewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        destinationViewController = ((UINavigationController *)viewController).topViewController;
    }

    if ([destinationViewController respondsToSelector:@selector(wasSelectedByTabBarController:)]) {
        [(id)destinationViewController wasSelectedByTabBarController:tabBarController];
    }
}

- (UIInterfaceOrientationMask)tabBarControllerSupportedInterfaceOrientations:(UITabBarController *)tabBarController {
    if (DEBUG_ROTATION) NSLog(@"AppDelegate:tabBarControllerSupportedInterfaceOrientations top %@ sel %@", AppDelegate.getTopMostViewController, tabBarController.selectedViewController);
    return tabBarController.selectedViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)tabBarControllerPreferredInterfaceOrientationForPresentation:(UITabBarController *)tabBarController {
    if (DEBUG_ROTATION) NSLog(@"AppDelegate:tabBarControllerPreferredInterfaceOrientationForPresentation top %@ sel %@", AppDelegate.getTopMostViewController, tabBarController.selectedViewController);
    return tabBarController.selectedViewController.preferredInterfaceOrientationForPresentation;
};

/*
 
 // The following three functions will not called, but left here for debugging purposes:
 
 -(NSUInteger)supportedInterfaceOrientations{
 NSLog(@"AppDelegate:supportedInterfaceOrientations");
 return UIInterfaceOrientationMaskPortrait;
 }
 
 - (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
 NSLog(@"AppDelegate:preferredInterfaceOrientationForPresentation");
 return UIInterfaceOrientationPortrait;
 }
 
 - (BOOL) shouldAutorotate {
 NSLog(@"AppDelegate:shouldAutorotate");
 return NO;
 }
 
 */


#pragma mark - Passcode Handling

- (BOOL) isPasscodeRequired {
    BOOL isEnabled = [PasscodeViewController passcodeEnabled];
    BOOL isExpired = NO;
    if (isEnabled) {
        //NSDate * lastTime = [[HXOUserDefaults standardUserDefaults] valueForKey:[[Environment sharedEnvironment] suffixedString:kHXOlastActiveDate]];
        NSDate * lastTime = [[HXOUserDefaults standardUserDefaults] valueForKey:[[Environment sharedEnvironment] suffixedString:kHXOlastLogOffDate]];
        NSTimeInterval dt = [[NSDate date] timeIntervalSinceDate: lastTime];
        isExpired = !lastTime || dt > [PasscodeViewController passcodeTimeout];
    }
    return isEnabled && isExpired;
}

- (void) requestUserAuthentication: (id) sender {
    UIStoryboard *storyboard = self.window.rootViewController.storyboard;
    PasscodeViewController *vc = [storyboard instantiateViewControllerWithIdentifier:@"PasscodeDialog"];
    vc.completionBlock = ^() {
        self.isLoggedOn = YES;
        [self.chatBackend enable];
        [self.chatBackend start: ![UserProfile sharedProfile].isRegistered];
    };
    UIViewController * root = self.window.rootViewController;
    if (root.presentedViewController) {
        [root dismissViewControllerAnimated: NO completion:^{
            [root presentViewController: vc animated: NO completion: nil];
        }];
    } else {
        [self.window.rootViewController presentViewController: vc animated: NO completion: nil];
    }
}

- (UIImage*) appIcon {
    NSArray * names = [[NSBundle mainBundle] infoDictionary][@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    UIImage * best;
    for (NSString * name in names) {
        UIImage * icon = [UIImage imageNamed: name];
        best = icon.size.width > best.size.width ? icon : best;
    }
    
    return best;
}
#pragma mark - Camera Snapshots

-(AVCaptureStillImageOutput *)openStillImageOutput {
    
    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    NSArray * codecTypes = stillImageOutput.availableImageDataCodecTypes;
    for (id type in codecTypes) {
        if (TRACE_MUGSHOTS) NSLog(@"codecType:%@",type);
    }

    NSArray * pixelTypes = stillImageOutput.availableImageDataCVPixelFormatTypes;
    for (id type in pixelTypes) {
        if (TRACE_MUGSHOTS) NSLog(@"pixelType:%@",type);
    }

    NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
    [stillImageOutput setOutputSettings:outputSettings];
    
    return stillImageOutput;
}

-(AVCaptureConnection *)findCameraConnection:(AVCaptureStillImageOutput*)stillImageOutput {

    //return [stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillImageOutput.connections) {
        if (TRACE_MUGSHOTS) NSLog(@"Check connection: %@", connection);
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if (TRACE_MUGSHOTS) NSLog(@"Check port: %@", port);
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                if (TRACE_MUGSHOTS) NSLog(@"Found port: %@, using connection %@", port, connection);
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    return videoConnection;
}

-(void)makeSnapShot:(AVCaptureStillImageOutput*)stillImageOutput
     fromConnection:(AVCaptureConnection *)videoConnection
             onDone:(void (^)(UIImage * image))handler
{
    
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                                  completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
                                                      
                                                      if (error == nil) {
                                                          NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
                                                          
                                                          UIImage *image = [[UIImage alloc] initWithData:imageData];
                                                          handler(image);
                                                     } else {
                                                          NSLog(@"makeSnapShot: error %@",error);
                                                          handler(nil);
                                                      }
                                                  }];
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position {
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)  {
        
        if ([device position] == position) {
            captureDevice = device;
            break;
        }
    }
    return captureDevice;
}

- (CGImageRef) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer // Create a CGImageRef from sample buffer data
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);        // Lock the image buffer
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);   // Get information of the image
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    /* CVBufferRelease(imageBuffer); */  // do not call this!
    
    return newImage;
}

- ( void ) captureOutput: ( AVCaptureOutput * ) captureOutput
   didOutputSampleBuffer: ( CMSampleBufferRef ) sampleBuffer
          fromConnection: ( AVCaptureConnection * ) connection
{
    if ( captureOutput == _videoOutput )
    {
        if (TRACE_MUGSHOTS) NSLog(@"captured sample buffer %lu", _captureCounter);
        
        if (++_captureCounter == 10) {
            if (TRACE_MUGSHOTS) NSLog(@"using sample buffer %lu", _captureCounter);
            
            CGImageRef cgImage = [self imageFromSampleBuffer:sampleBuffer];
            UIImage *image = [UIImage imageWithCGImage: cgImage scale:1.0f orientation:UIImageOrientationRight];
            CGImageRelease( cgImage );
            
            dispatch_async(dispatch_get_main_queue(), ^{
                _captureHandler(image);
            });
            dispatch_async(_sessionQueue, ^{
                [ _captureSession stopRunning];
            });
        }
    }
}
#ifdef USE_STILL_IMAGE_API
- ( void ) cameraStarted: ( NSNotification * ) note
{
    NSLog(@"cameraStarted");
    // This callback has done its job, now disconnect it
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self
                                                       name: AVCaptureSessionDidStartRunningNotification
                                                     object: _captureSession ];

    AVCaptureConnection *videoConnection =[self findCameraConnection:_stillImageOutput];
    [self makeSnapShot:_stillImageOutput fromConnection:videoConnection onDone:^(UIImage *image) {
        [ _captureSession stopRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            _captureHandler(image);
        });
    }];

}
#endif

-(void)makeSnapShot:(void (^)(UIImage * image))handler {
    
    if (_sessionQueue == nil) {
        _sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    }
    
    dispatch_async(_sessionQueue, ^{
        _captureSession = [[AVCaptureSession alloc] init];
        
         _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
        
        AVCaptureDevice * currentDevice = nil;
        NSArray *devices = [AVCaptureDevice devices];
        for (AVCaptureDevice *device in devices) {
            if (TRACE_MUGSHOTS) NSLog(@"Device name: %@", [device localizedName]);
            if ([device hasMediaType:AVMediaTypeVideo]) {
                if ([device position] == AVCaptureDevicePositionBack) {
                    if (TRACE_MUGSHOTS) NSLog(@"Device position : back");
                } else {
                    if (TRACE_MUGSHOTS) NSLog(@"Device position : front");
                    currentDevice = device;
                }
            }
        }
        
        if ( [currentDevice lockForConfiguration:NULL] == YES ) {
            if ([currentDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                if (TRACE_MUGSHOTS) NSLog(@"Setting Focus");
                CGPoint autofocusPoint = CGPointMake(0.5f, 0.5f);
                [currentDevice setFocusPointOfInterest:autofocusPoint];
                [currentDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            }
            
            if ([currentDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                if (TRACE_MUGSHOTS) NSLog(@"Setting Exposure");
                CGPoint exposurePoint = CGPointMake(0.5f, 0.5f);
                [currentDevice setExposurePointOfInterest:exposurePoint];
                [currentDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
                //[currentDevice setExposureMode:AVCaptureExposureModeAutoExpose];
                if (currentDevice.lowLightBoostSupported) {
                    currentDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
                }
                if (TRACE_MUGSHOTS)NSLog(@"low light supported: %d enabled: %d autoenable: %d",currentDevice.lowLightBoostSupported, currentDevice.isLowLightBoostEnabled,currentDevice.automaticallyEnablesLowLightBoostWhenAvailable);
                if (TRACE_MUGSHOTS) NSLog(@"adjusted exposure");
            }
            
            // Set a minimum frame rate of 5 frames per second
            [currentDevice setActiveVideoMinFrameDuration: CMTimeMake( 1, 5 ) ];
            
            // and a maximum of 30 frames per second
            [currentDevice setActiveVideoMaxFrameDuration: CMTimeMake( 1, 30 ) ];
            [currentDevice unlockForConfiguration];
        }
        
        // Add inputs and outputs.
        NSError *error = nil;
        
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:currentDevice error:&error];
        
        if (!input) {
            // Handle the error appropriately.
            NSLog(@"capture input creation failed, error=%@",error);
        }
        
        [ _captureSession addInput:input];
#ifdef USE_STILL_IMAGE_API
        _stillImageOutput = [self openStillImageOutput];
        [ _captureSession addOutput:_stillImageOutput];
#endif
        _videoOutput = [ [ AVCaptureVideoDataOutput alloc ] init ];
        dispatch_queue_t captureQueue = dispatch_queue_create( "captureQueue", DISPATCH_QUEUE_SERIAL );
        
        [ _videoOutput setSampleBufferDelegate: self queue: captureQueue ];
        _videoOutput.alwaysDiscardsLateVideoFrames = NO;
        NSNumber * framePixelFormat = [ NSNumber numberWithInt: kCVPixelFormatType_32BGRA ];
        _videoOutput.videoSettings = [ NSDictionary dictionaryWithObject: framePixelFormat
                                                                   forKey: ( id ) kCVPixelBufferPixelFormatTypeKey ];
        [_captureSession addOutput: _videoOutput ];
        
        _captureHandler = handler;
#ifdef USE_STILL_IMAGE_API
        [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                    selector: @selector( cameraStarted: )
                                                        name: AVCaptureSessionDidStartRunningNotification
                                                      object: _captureSession ];
#endif
        _captureCounter = 0;
        [ _captureSession startRunning];
        
    });
}

+ (UIImage *)loadBackgroundImage:(NSString *)name {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize screenSize = CGSizeMake(screenBounds.size.width * screenScale, screenBounds.size.height * screenScale);
    
    NSString *imageName = [NSString stringWithFormat:@"%@%dx%d", name, (int)screenSize.width, (int)screenSize.height];
    NSLog(@"Loading image %@", imageName);
    UIImage *image = [UIImage imageNamed:imageName];
    NSLog(@"image = %@", image);
    return image;
}
typedef bool(^contactPredicate)(id contactOrGroup);

- (void) updateNickNamesFromRequestTemplate: (NSString*) fetchRequestName
                           withUserDefaults: (NSUserDefaults*) sharedData
                                  usingKeyPattern: (NSString*) keyPattern
                                    oldKeys: (NSMutableArray*) staleKeys
                                  predicate: (contactPredicate) predicate
{
    NSFetchRequest * fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName: fetchRequestName
                                                                        substitutionVariables: @{}];
    NSError * error = nil;
    NSArray * contacts = [self.mainObjectContext executeFetchRequest: fetchRequest error: &error];
    if (contacts == nil) {
        NSLog(@"Fetch request '%@' failed: %@", fetchRequestName, error);
        abort();
    }
    for (id contact in contacts) {
        if (predicate(contact)) {
            NSString * key = [NSString stringWithFormat: keyPattern, [contact clientId]];
            if ([staleKeys indexOfObject: key] != NSNotFound) {
                [staleKeys removeObject: key];
            }
            [sharedData setObject: [contact nickName] forKey: key];
        }
    }
}

- (void) updateNotificationServiceExtensionNickNameTables {
    NSUserDefaults * sharedData = [[NSUserDefaults alloc] initWithSuiteName: [self appGroupId]];
    NSMutableArray * staleKeys = [[sharedData dictionaryRepresentation].allKeys mutableCopy];

    [self updateNickNamesFromRequestTemplate: @"LiveContacts"
                            withUserDefaults: sharedData
                             usingKeyPattern: @"nickName.contact.%@"
                                     oldKeys: staleKeys
                                   predicate: ^bool(Contact * contact) {
                                       return [contact.relationshipState isEqualToString: kRelationStateFriend] ||
                                              [contact.relationshipState isEqualToString: kRelationStateGroupFriend] ||
                                              [contact.relationshipState isEqualToString: kRelationStateInvited];
                                   }];

    [self updateNickNamesFromRequestTemplate: @"LiveGroups"
                            withUserDefaults: sharedData
                             usingKeyPattern: @"nickName.group.%@"
                                     oldKeys: staleKeys
                                   predicate: ^bool(Group * group) {
                                       return [group.groupState isEqualToString: kGroupStateExists];
                                   }];

    for (NSString * key in staleKeys) {
        [sharedData removeObjectForKey: key];
    }
}

- (NSString*) appGroupId {
    NSString * groupIdSetting = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"HXOAppGroupId"];
    if (groupIdSetting != nil) {
        return groupIdSetting;
    }
    return [NSString stringWithFormat: @"group.%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"]];
}

@end


#ifdef DEBUG_RESPONDER

#import <objc/runtime.h>

@implementation UIResponder (MYHijack)
+ (void)hijackSelector:(SEL)originalSelector withSelector:(SEL)newSelector
{
    Class class = [UIResponder class];
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method categoryMethod = class_getInstanceMethod(class, newSelector);
    method_exchangeImplementations(originalMethod, categoryMethod);
}

+ (void)hijack
{
    [self hijackSelector:@selector(touchesBegan:withEvent:) withSelector:@selector(MYHijack_touchesBegan:withEvent:)];
}

- (void)MYHijack_touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"touchesBegan self=%@, touches=%@", self, touches);
    for (UITouch * t in touches) {
        NSLog(@"touch=%@",t);
        NSLog(@"gestureRecognizers#=%d",t.gestureRecognizers.count);
        for (UIGestureRecognizer * r in t.gestureRecognizers) {
            NSLog(@"recognizer=%@",r);
        }
    }
    NSLog(@"Responder Chain %@", NBResponderChain());
    [self MYHijack_touchesBegan:touches withEvent:event]; // Calls the original version of this method
}
@end

#endif


