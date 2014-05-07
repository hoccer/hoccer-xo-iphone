//
//  AppDelegate.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AppDelegate.h"

#import "ConversationViewController.h"
#import "Contact.h"
#import "Attachment.h"
#import "HXOMessage.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "HXOUserDefaults.h"
#import "Environment.h"
#import "UserProfile.h"
#import "UIAlertView+BlockExtensions.h"
#import "ZipArchive.h"
#import "TestFlight.h"
#import "HXOUI.h"
#import "ChatViewController.h"
#import "ModalTaskHUD.h"

#import "OpenSSLCrypto.h"
#import "Crypto.h"
#import "CCRSA.h"

#ifdef WITH_WEBSERVER
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "MyHttpConnection.h"
#endif

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>

#import <CoreData/NSMappingModel.h>

#import <AVFoundation/AVFoundation.h>

#define CONNECTION_TRACE NO
#define MIGRATION_DEBUG NO
#define AUDIOSESSION_DEBUG NO
#define TRACE_DATABASE_SAVE YES

#ifdef HOCCER_DEV
NSString * const kHXOURLScheme = @"hxod";
static NSString * const kTestFlightAppToken = @"c5ada956-43ec-4e9e-86e5-0a3bd3d9e20b";
#else
NSString * const kHXOURLScheme = @"hxo";
static NSString * const kTestFlightAppToken = @"26645843-f312-456c-8954-444e435d4ad2";
#endif

static NSInteger validationErrorCount = 0;

#ifdef WITH_WEBSERVER
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#endif


@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

#ifdef WITH_WEBSERVER
@synthesize httpServer = _httpServer;
#endif

@synthesize rpcObjectModel = _rpcObjectModel;

@synthesize userAgent;

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
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}

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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"Running with environment %@", [Environment sharedEnvironment].currentEnvironment);

#ifdef DEBUG
//#define DEFINE_OTHER_SERVERS
#ifdef DEFINE_OTHER_SERVERS
    //[[HXOUserDefaults standardUserDefaults] setValue: @"ws://10.1.9.209:8080/" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"http://10.1.9.209:8081/" forKey: kHXOForceFilecacheURL];
    
    [[HXOUserDefaults standardUserDefaults] setValue: @"ws://192.168.2.146:8080/" forKey: kHXODebugServerURL];
    [[HXOUserDefaults standardUserDefaults] setValue: @"http://192.168.2.146:8081/" forKey: kHXOForceFilecacheURL];
    
    //[[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXOForceFilecacheURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
#endif
#endif
    
    if ([[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOReportCrashes] boolValue]) {
        [TestFlight takeOff: kTestFlightAppToken];
    } else {
        NSLog(@"TestFlight crash reporting is disabled");
    }

    if (!UserProfile.sharedProfile.hasKeyPair) {
        dispatch_async(dispatch_get_main_queue(), ^{ // delay until window is realized
            ModalTaskHUD * hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"key_renewal_hud_title", nil)];
            [hud show];
            [UserProfile.sharedProfile renewKeypairWithCompletion:^{
                [hud dismiss];
            }];
        });
    }
    
    application.applicationSupportsShakeToEdit = NO;

    if ([self persistentStoreCoordinator] == nil) {
        return NO;
    }
#ifdef WITH_WEBSERVER
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
#endif
    [self registerForRemoteNotifications];
    
    [self checkForCrash];
    self.chatBackend = [[HXOBackend alloc] initWithDelegate: self];

    NSString * storyboardName = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? @"MainStoryboard_iPad" : @"MainStoryboard_iPhone";
    [UIStoryboard storyboardWithName: storyboardName bundle: [NSBundle mainBundle]];

    [[HXOUI theme] setupTheming];

    // NSLog(@"%@:%d", [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone], [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]);
    BOOL isFirstRun = ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];

    if (isFirstRun) {
        dispatch_async(dispatch_get_main_queue(), ^{  // delay until window is realized
            [self.window.rootViewController performSegueWithIdentifier: @"showSetup" sender: self];
        });
    } else {
        [self setupDone: NO];
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
    [[HXOUserDefaults standardUserDefaults] setValue:buildNumber forKey: [[Environment sharedEnvironment] suffixedString:kHXOlatestBuildRun]];
    
    self.internetReachabilty = [GCNetworkReachability reachabilityForInternetConnection];
    [self.internetReachabilty startMonitoringNetworkReachabilityWithNotification];
    

    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] != nil) {
        // TODO: jump to conversation
        NSLog(@"Launched by remote notification.");
    }
    
    [AppDelegate setDefaultAudioSession];

    [self setLastActiveDate];

    
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

+ (void) setDefaultAudioSession {
    if (AUDIOSESSION_DEBUG) NSLog(@"setDefaultAudioSession");
    //NSLog(@"%@", [NSThread callStackSymbols]);
    NSError * myError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    [session setActive:NO error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to deactivate prior audio session, error=%@",myError);
    }

    [session setCategory:AVAudioSessionCategoryAmbient error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to set audio category AVAudioSessionCategoryAmbient, error=%@",myError);
    }
    
    [session setActive:YES error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to activate audio session for category AVAudioSessionCategoryAmbient, error=%@",myError);
    }
}

+ (void) setRecordingAudioSession {
    if (AUDIOSESSION_DEBUG) NSLog(@"setRecordingAudioSession");

    NSError * myError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    [session setActive:NO error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to deactivate prior audio session, error=%@",myError);
    }
    
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&myError];
    //[session setCategory:AVAudioSessionCategoryRecord error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to set audio category AVAudioSessionCategoryRecord, error=%@",myError);
    }
    
    [session setActive:YES error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to activate audio session for category AVAudioSessionCategoryRecord, error=%@",myError);
    }
    [AppDelegate requestRecordPermission];
}

+ (void) setProcessingAudioSession {
    if (AUDIOSESSION_DEBUG) NSLog(@"setProcessingAudioSession");
    NSError * myError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    [session setActive:NO error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to deactivate prior audio session, error=%@",myError);
    }
    
    [session setCategory:AVAudioSessionCategoryAudioProcessing error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to set audio category AVAudioSessionCategoryRecord, error=%@",myError);
    }
    
    [session setActive:YES error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to activate audio session for category AVAudioSessionCategoryRecord, error=%@",myError);
    }
}


+ (void) setMusicAudioSession {
    if (AUDIOSESSION_DEBUG) NSLog(@"setMusicAudioSession");
    NSError * myError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    [session setActive:NO error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to deactivate prior audio session, error=%@",myError);
    }
    
    [session setCategory:AVAudioSessionCategoryPlayback error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to set audio category AVAudioSessionCategorySoloAmbient, error=%@",myError);
    }
    [session setActive:YES error:&myError];
    if (myError != nil) {
        NSLog(@"ERROR: failed to activate audio session for category AVAudioSessionCategorySoloAmbient, error=%@",myError);
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
                                                     message: NSLocalizedString(@"permission_denied_microphone_message", nil)
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
    // NSLog(@"setupDone");
    [self.chatBackend start: performRegistration];
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
    [self saveDatabaseNow];
    [self setLastActiveDate];
    [self updateUnreadMessageCountAndStop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [self.chatBackend start: NO];
    [self setLastActiveDate];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
    [self setLastDeactivationDate];
}

#pragma mark - Core Data stack

- (void)saveContext
{
    NSDate * start;
    if (TRACE_DATABASE_SAVE) {
        NSLog(@"Saving database");
        start = [[NSDate alloc] init];
    }
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
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
                        msg = [NSString stringWithFormat:@"Unknown error (code %i).", [error code]];
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

- (void)saveDatabase
{
    NSString * savePolicy = [[HXOUserDefaults standardUserDefaults] objectForKey: kHXOSaveDatabasePolicy];
    if (![savePolicy isEqualToString:kHXOSaveDatabasePolicyDelayed]) {
        [self saveContext];
        return;
    }

    [self.nextDatabaseSaveTimer invalidate];
    
    [self.managedObjectContext processPendingChanges]; // will perform all UI changes

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
    // NSLog(@"Saved database at %@",self.lastDatebaseSaveDate);
}

- (void)saveDatabaseNow
{
    [self.nextDatabaseSaveTimer invalidate];
    self.nextDatabaseSaveTimer = nil;
    [self saveContext];
    self.lastDatebaseSaveDate = [NSDate date];
}

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
        [_managedObjectContext setUndoManager: nil];
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
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *) applicationLibraryDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
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
    fetchRequest.entity = [NSEntityDescription entityForName: [HXOMessage entityName] inManagedObjectContext: self.managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isRead == NO"];

    NSError *error = nil;
    NSUInteger numberOfRecords = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];

    if (numberOfRecords == NSNotFound) {
        NSLog(@"ERROR: unreadMessageCount: failed to count unread messages: %@", error);
        abort();
    }
    return numberOfRecords;
}

- (void) updateUnreadMessageCountAndStop {
    NSUInteger unreadMessages = [self unreadMessageCount];
    [UIApplication sharedApplication].applicationIconBadgeNumber = unreadMessages;
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self.chatBackend stop];
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.chatBackend hintApnsUnreadMessage: unreadMessages handler: ^(BOOL success){
            if (CONNECTION_TRACE) NSLog(@"updated unread message count: %@", success ? @"success" : @"failed");
            [self.chatBackend stop];
        }];
    });
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

/* nothing to do here ... ?
- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
}
*/

#pragma mark - URL Handling

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[url scheme] isEqualToString: kHXOURLScheme]) {
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
    return NO;
}

+(BOOL)zipDirectoryAtURL:(NSURL*)theDirectoryURL toZipFile:(NSURL*)zipFileURL {
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
                    NSLog(@"added to zip: %@",subpath);
                    NSString * fullPath = [[theDirectoryURL path] stringByAppendingPathComponent: subpath];
                    //NSLog(@"fullPath=%@",fullPath);
                    if([zip addFileToZip:fullPath newname:subpath]) {
                        //NSLog(@"File '%@' Added to zip as '%@'",fullPath,subpath);
                    } else {
                        NSLog(@"#ERROR: Failed to add file '%@' Added to zip as '%@'",fullPath,subpath);
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



- (BOOL)handleFileURL: (NSURL *)url withDocumentType:(NSString*)documentType
{
    NSString *fileName = [url lastPathComponent];
    NSURL *destURL = [AppDelegate uniqueNewFileURLForFileLike:fileName];
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
            if ([AppDelegate zipDirectoryAtURL:url toZipFile:zipfile]) {
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
        } else {
            mediaType=@"data";
        }
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
                                          cancelButtonTitle:@"ok"
                                          otherButtonTitles:nil];

    [alert show];
}


- (void) showFatalErrorAlertWithMessage:  (NSString *) message withTitle:(NSString *) title {
    if (title == nil) {
        title = NSLocalizedString(@"fatal_error_default_title", nil);
    }
    if (message == nil) {
        message = NSLocalizedString(@"fatal_error_default_message", @"Error Alert Message");
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   completionBlock: ^(NSUInteger buttonIndex,UIAlertView* alertView) { exit(1); }
                                          cancelButtonTitle:@"ok"
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
        [self showFatalErrorAlertWithMessage: NSLocalizedString(message_tag, nil) withTitle: NSLocalizedString(title_tag, nil)];

    };

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no", nil)
                                          otherButtonTitles:NSLocalizedString(@"database_delete_btn_title",nil),nil];
    [alert show];
}

- (void) showInvalidCredentialsWithContinueHandler:(ContinueBlock)onNotDeleted {
    
    HXOAlertViewCompletionBlock completionBlock = ^(NSUInteger buttonIndex, UIAlertView * alert) {
        NSString * title_tag;
        NSString * message_tag;
        switch (buttonIndex) {
            case 0:
                {
                    title_tag = @"credentials_and_database_not_deleted_title";
                    message_tag = @"credentials_and_database_not_deleted_message";
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title_tag
                                                                    message: message_tag
                                                            completionBlock: onNotDeleted
                                                          cancelButtonTitle:@"Continue"
                                                          otherButtonTitles:nil];
                    [alert show];
                }
                break;
            case 1:
                [[UserProfile sharedProfile] deleteCredentials];
                [self deleteDatabase];
                title_tag = @"credentials_and_database_deleted_title";
                message_tag = @"credentials_and_database_deleted_message";
                [self showFatalErrorAlertWithMessage: NSLocalizedString(message_tag, nil) withTitle: NSLocalizedString(title_tag, nil)];
                break;
        }
        
    };
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"credentials_invalid_title", nil)
                                                    message: NSLocalizedString(@"credentials_invalid_delete_question", nil)
                                            completionBlock: completionBlock
                                          cancelButtonTitle:NSLocalizedString(@"no",nil)
                                          otherButtonTitles:NSLocalizedString(@"credentials_database_delete_btn_title",nil),nil];
    [alert show];
}

-(void) dumpAllRecordsOfEntityNamed:(NSString *)theEntityName {
    NSEntityDescription *entity = [NSEntityDescription entityForName:theEntityName inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [NSFetchRequest new];
    [request setEntity:entity];
    NSError *error;
    NSMutableArray *fetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    int i = 0;
    for (NSManagedObject * object in fetchResults) {
        NSLog(@"================== Showing object %d of entity '%@' =================", i, theEntityName);
        NSLog(@"================== id = %@",object.objectID);
        for (NSAttributeDescription * property in entity) {
            // NSLog(@"property '%@'", property.name);
            NSString * description = [[object valueForKey:property.name] description];
            if (description.length > 256) {
                description = [NSString stringWithFormat:@"%@...(%d chars not shown)", [description substringToIndex:255],description.length-256];
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
        NSLog(@"backendDidStop: done with background task ... good night");
        [[UIApplication sharedApplication] endBackgroundTask: _backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
}

-(void) didFailWithInvalidCertificate:(DoneBlock)done {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"certificate_invalid_title", nil)
                                                     message: NSLocalizedString(@"certificate_invalid_message", nil)
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

+ (NSURL *)uniqueNewFileURLForFileLike:(NSString *)fileNameHint {
    
    NSString *newFileName = [AppDelegate sanitizeFileNameString: fileNameHint];
    NSURL * appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
    NSString * myDocDir = [appDocDir path];
    NSString * myUniqueNewFile = [[self class]uniqueFilenameForFilename: newFileName inDirectory: myDocDir];
    NSString * savePath = [myDocDir stringByAppendingPathComponent: myUniqueNewFile];
    NSURL * myLocalURL = [NSURL fileURLWithPath:savePath];
    return myLocalURL;
}

@synthesize peoplePicker = _peoplePicker;
- (ABPeoplePickerNavigationController*) peoplePicker {
    if ( ! _peoplePicker) {
        _peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
    }
    return _peoplePicker;
}

+ (AppDelegate*)instance {
    return (AppDelegate*)[[UIApplication sharedApplication] delegate];
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

#ifdef WITH_WEBSERVER

-(HTTPServer*)httpServer {
    if (_httpServer == nil) {
        // Create server using our custom MyHTTPServer class
        _httpServer = [[HTTPServer alloc] init];
        [_httpServer setConnectionClass:[MyHTTPConnection class]];

        // Tell the server to broadcast its presence via Bonjour.
        // This allows browsers such as Safari to automatically discover our service.
        [_httpServer setType:@"_http._tcp."];

        [_httpServer setPort:8899];

        // Normally there's no need to run our server on any specific port.
        // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
        // However, for easy testing you may want force a certain port so you can just hit the refresh button.
        // [httpServer setPort:12345];

        // Serve files from our embedded Web folder
        //        NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
        NSString *webPath = [self.applicationDocumentsDirectory path];
        DDLogInfo(@"Setting document root: %@", webPath);

        [_httpServer setDocumentRoot:webPath];
    }
    return _httpServer;
}

- (void)startHttpServer
{
    // Start the server (and check for problems)

	NSError *error;
	if([self.httpServer start:&error])
	{
		DDLogInfo(@"Started HTTP Server on port %hu", [self.httpServer listeningPort]);
	}
	else
	{
		DDLogError(@"Error starting HTTP Server: %@", error);
	}
}

- (void)stopHttpServer {
    if (_httpServer) {
        [_httpServer stop];
    }
}
-(BOOL)httpServerIsRunning {
    if (_httpServer) {
        return _httpServer.isRunning;
    }
    return NO;
}
#endif

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



