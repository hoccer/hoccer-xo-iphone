//
//  AppDelegate.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AppDelegate.h"

#import "HXOConfig.h"

#import "ConversationViewController.h"
#import "Contact.h"
#import "HXOMessage.h"
#import "AssetStore.h"
#import "NavigationMenuViewController.h"
#import "ContactQuickListViewController.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "InviteCodeViewController.h"
#import "HXOUserDefaults.h"
#import "Environment.h"
#import "UserProfile.h"
#import "MFSideMenu.h"
#import "UIAlertView+BlockExtensions.h"

#import <CoreData/NSMappingModel.h>

#import <AVFoundation/AVFoundation.h>

#define CONNECTION_TRACE NO
#define MIGRATION_DEBUG NO
#define AUDIOSESSION_DEBUG NO

typedef void(^HXOAlertViewCompletionBlock)(NSUInteger, UIAlertView*);

static const NSInteger kFatalDatabaseErrorAlertTag = 100;
static const NSInteger kDatabaseDeleteAlertTag = 200;
static NSInteger validationErrorCount = 0;

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


@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

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
 
    // [[HXOUserDefaults standardUserDefaults] setBool: NO forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];

    if ([self persistentStoreCoordinator] == nil) {
        return NO;
    }
    
    [self registerForRemoteNotifications];
    
    [self checkForCrash];
    self.chatBackend = [[HXOBackend alloc] initWithDelegate: self];

    UIStoryboard *storyboard = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        /*
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        self.navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)self.navigationController.topViewController;
        UINavigationController *masterNavigationController = splitViewController.viewControllers[0];
        self.conversationViewController = (ConversationViewController *)masterNavigationController.topViewController;
         */
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:[NSBundle mainBundle]];
    } else {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:[NSBundle mainBundle]];
        /*
        self.navigationController = (UINavigationController *)self.window.rootViewController;
        UIViewController * myStartupVC = self.navigationController.topViewController;
        [myStartupVC performSegueWithIdentifier:@"startupReady" sender:myStartupVC];
        
        self.navigationController.viewControllers = @[self.navigationController.topViewController]; // make new root controller
        self.conversationViewController = (ConversationViewController *)self.navigationController.topViewController;
         */
    }

    [self setupSideMenusWithStoryboard: storyboard];

    if ([[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
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
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"microphone_access_denied_title", nil)
                                                     message: NSLocalizedString(@"microphone_access_denied_message", nil)
                                             completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alertView) { }
                                           cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

- (void) seedRand {
    unsigned seed;
    SecRandomCopyBytes(kSecRandomDefault, sizeof seed, (uint8_t*)&seed);
    srand(seed);
}

- (void) setupSideMenusWithStoryboard: (UIStoryboard*) storyboard {
    UINavigationController * navigationController = [storyboard instantiateViewControllerWithIdentifier:@"navigationController"];
    ContactQuickListViewController * contactListViewController = [storyboard instantiateViewControllerWithIdentifier:@"contactListViewController"];
    NavigationMenuViewController * navigationMenuViewController = [storyboard instantiateViewControllerWithIdentifier:@"navigationMenuViewController"];
    MFSideMenuContainerViewController * container = (MFSideMenuContainerViewController*)self.window.rootViewController;
    [container setCenterViewController: navigationController];
    [container setLeftMenuViewController: navigationMenuViewController];
    [container setRightMenuViewController: contactListViewController];

    [container setMenuWidth: 256];
    [container setMenuSlideAnimationEnabled: YES];
    [container setMenuSlideAnimationFactor: 320.0/64];

    self.conversationViewController = (ConversationViewController *)navigationController.topViewController;
    contactListViewController.conversationViewController = self.conversationViewController;
    navigationController.delegate = navigationMenuViewController;
    [navigationMenuViewController cacheViewController: self.conversationViewController withStoryboardId: @"conversationViewController"];
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
#ifdef DEBUG
    NSLog(@"Saving database");
    NSDate * start = [[NSDate alloc] init];
#endif
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
#ifdef DEBUG
    double elapsed = -[start timeIntervalSinceNow];
    NSLog(@"Saving database took %f secs", elapsed);
#endif
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
                                                  cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
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
                                 NSInferMappingModelAutomaticallyOption : @(YES)};
            
            
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
        userAgent = [NSString stringWithFormat: @"%@ %@ / %@ / %@ %@",
                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
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
    if ([[url scheme] isEqualToString:@"hxo"]) {
        // TODO: input verification
        [self.chatBackend acceptInvitation: url.host];
    }
    return NO;
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
        title = NSLocalizedString(@"Invite failed", @"Invite Alert Title");
        message = NSLocalizedString(@"The server rejected your invite code", @"Invite Alert Message");
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];

    // Work around for an issue with the side menu. When opening an alert while the side menu is open or in
    // transition a matrix becomes singular and the side menus dissappear in numeric nirvana. We're going to
    // make the side menu a plain menu anyway. No buttons or other user interaction. So, a workaround is ok for now.
    [NSTimer scheduledTimerWithTimeInterval: 1.0 target: alert selector: @selector(show) userInfo: nil repeats: NO];
}

+ (void) showErrorAlertWithMessage: (NSString *) message withTitle:(NSString *) title {

    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(title, nil)
                                                     message: NSLocalizedString(message, nil)
                                                    delegate: nil
                                           cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                           otherButtonTitles: nil];
    [alert show];
}
    
+ (void) showErrorAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title {
    dispatch_async(dispatch_get_main_queue(), ^{
        [AppDelegate showErrorAlertWithMessage:message withTitle:title];
    });
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
                                          cancelButtonTitle:@"OK"
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
                title_tag = @"corrupt_database_not_deleted_title";
                message_tag = @"corrupt_database_not_deleted_message";
                break;
            case 1:
                [self deleteDatabase];
                title_tag = @"corrupt_database_deleted_title";
                message_tag = @"corrupt_database_deleted_message";
                break;
        }
        [self showFatalErrorAlertWithMessage: NSLocalizedString(message_tag, nil) withTitle: NSLocalizedString(title_tag, nil)];

    };

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   completionBlock: completionBlock
                                          cancelButtonTitle:@"No"
                                          otherButtonTitles:@"Delete Database",nil];
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
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"invalid_cert_title", nil)
                                                     message: NSLocalizedString(@"invalid_cert_message", nil)
                                             completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alertView) { done(); }
                                           cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

- (void) connectionStatusDidChange {
    self.navigationController.topViewController.navigationItem.prompt = @"blub";
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


@end

