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
#import "AttachmentMigration.h"
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
#import "GesturesInterpreter.h"
#import "HXOEnvironment.h"
#import "HXOAudioPlayer.h"
#import "AudioAttachmentListViewController.h"

#import "Delivery.h" //DEBUG

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


#ifdef HOCCER_DEV
NSString * const kHXOURLScheme = @"hxod";
static NSString * const kTestFlightAppToken = @"c5ada956-43ec-4e9e-86e5-0a3bd3d9e20b";
#else
    #ifdef HOCCER_CLASSIC
        NSString * const kHXOURLScheme = @"hcr";
        static NSString * const kTestFlightAppToken = @"26645843-f312-456c-8954-444e435d4ad2";
    #else
        NSString * const kHXOURLScheme = @"hxo";
        static NSString * const kTestFlightAppToken = @"26645843-f312-456c-8954-444e435d4ad2";
    #endif
#endif

NSString * const kHXOTransferCredentialsURLImportScheme = @"hcrimport";
NSString * const kHXOTransferCredentialsURLCredentialsHost = @"credentials";
NSString * const kHXOTransferCredentialsURLArchiveHost = @"archive";
NSString * const kHXOTransferCredentialsURLExportScheme = @"hcrexport";
NSString * const kHXOTransferArchiveUTI = @"com.hoccer.ios.archive.v1";
NSString * const kHXODefaultArchiveName = @"default.hciarch";

static NSInteger validationErrorCount = 0;

#ifdef WITH_WEBSERVER
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#endif

@interface AppDelegate ()
{
    NSMutableArray * _inspectedObjects;
    NSMutableArray * _inspectors;
    NSMutableDictionary *_idLocks;
    NSObject * _inspectionLock;
    NSMutableDictionary * _backgroundContexts;
    
}

@property (nonatomic, strong) ModalTaskHUD * hud;
@property (nonatomic, strong) UIViewController * interactionViewController;
@property (nonatomic, strong) UIView * interactionView;

@end

@implementation AppDelegate

@synthesize mainObjectContext = _mainObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize inNearbyMode = _inNearbyMode;

#ifdef WITH_WEBSERVER
@synthesize httpServer = _httpServer;
#endif

@synthesize rpcObjectModel = _rpcObjectModel;
@synthesize userAgent;

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
    
    _idLocks = [NSMutableDictionary new];
    _backgroundContexts = [NSMutableDictionary new];
    _inspectionLock = [NSObject new];

#ifdef DEBUG
//#define DEFINE_OTHER_SERVERS
#endif
#ifdef DEFINE_OTHER_SERVERS
    //[[HXOUserDefaults standardUserDefaults] setValue: @"ws://10.1.9.166:8080/" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"http://10.1.9.166:8081/" forKey: kHXOForceFilecacheURL];
    
    //[[HXOUserDefaults standardUserDefaults] setValue: @"wss://talkserver.talk.hoccer.de:8443/" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"https://filecache.talk.hoccer.de:8444/" forKey: kHXOForceFilecacheURL];

    [[HXOUserDefaults standardUserDefaults] setValue: @"ws://192.168.2.146:8080/" forKey: kHXODebugServerURL];
    [[HXOUserDefaults standardUserDefaults] setValue: @"http://192.168.2.146:8081/" forKey: kHXOForceFilecacheURL];
    
    //[[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXODebugServerURL];
    //[[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXOForceFilecacheURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
#else
    [[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXODebugServerURL];
    [[HXOUserDefaults standardUserDefaults] setValue: @"" forKey: kHXOForceFilecacheURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
#endif
    
    if ([[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOReportCrashes] boolValue]) {
        [TestFlight takeOff: kTestFlightAppToken];
    } else {
        NSLog(@"TestFlight crash reporting is disabled");
    }
    
    if (!UserProfile.sharedProfile.hasKeyPair) {
        dispatch_async(dispatch_get_main_queue(), ^{ // delay until window is realized
            [AppDelegate renewRSAKeyPairWithSize: kHXODefaultKeySize];
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

    if (isFirstRun || ![UserProfile sharedProfile].isRegistered) {
        [self.chatBackend disable];
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
    if ([UserProfile sharedProfile].isRegistered && (![UserProfile sharedProfile].foundCredentialsBackup || self.runningNewBuild)) {
        [[UserProfile sharedProfile] backupCredentials];
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

    [AttachmentMigration determinePlayabilityForAllAudioAttachments];

    NSAssert([self.window.rootViewController isKindOfClass:[UITabBarController class]], @"Expecting UITabBarController");
    ((UITabBarController *)self.window.rootViewController).delegate = self;
    
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
    NSLog(@"setupDone");
    [self.chatBackend enable];
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
    [self.chatBackend changePresenceToNotTyping]; // not typing anymore ... yep, pretty sure...
    [self saveDatabaseNow];
    [self setLastActiveDate];
    if (self.inNearbyMode) {
        [self suspendNearbyMode]; // for resuming nearby mode, the Conversations- or ChatView are responsible; the must do it after login
    }
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

#pragma mark - Nearby

-(void)configureForNearbyMode:(BOOL)modeNearby {
    if (TRACE_NEARBY_ACTIVATION) NSLog(@"AppDelegate:configureForNearbyMode= %d", modeNearby);
    [HXOEnvironment.sharedInstance setActivation:modeNearby];
    if (modeNearby) {
        [GesturesInterpreter.instance start];
    } else {
        [GesturesInterpreter.instance stop];
    }
    _inNearbyMode = modeNearby;
}

-(void)suspendNearbyMode {
    NSLog(@"suspendNearbyMode");
    [HXOEnvironment.sharedInstance deactivateLocation];
    [GesturesInterpreter.instance stop];
}

-(BOOL)inNearbyMode {
    return _inNearbyMode;
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
            
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Starting backgroundblock of ctx %@", temporaryContext);
            
            backgroundBlock(temporaryContext);
            
            if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished backgroundblock of ctx %@, pushing to parent", temporaryContext);
            
            // push to parent
            if ([temporaryContext hasChanges]) {
                [self saveContext:temporaryContext];
                
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Finished saving to parent of ctx %@, pushing done", temporaryContext);
                
                // save parent to disk
                [mainMOC performBlockAndWait:^{
                    if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes of ctx %@,", temporaryContext);
                    [self saveDatabaseNow];
                    if (TRACE_BACKGROUND_PROCESSING) NSLog(@"Saving backgroundblock changes done of ctx %@,", temporaryContext);
                }];
            } else {
                if (TRACE_BACKGROUND_PROCESSING) NSLog(@"No uncommited changes for backgroundblock of ctx %@,", temporaryContext);
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
            NSLog(@"could not fetch managed object from id %@, error=%@", objId, error);
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
            NSLog(@"could not fetch managed object %d from id %@, error=%@", num, objId, error);
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


- (BOOL) openWithInteractionController:(NSURL *)myURL withUTI:(NSString*)uti withName:(NSString*)name inView:(UIView*)view withController:(UIViewController*)controller{
    NSLog(@"openWithInteractionController");
    if (self.interactionView != nil) {
        NSLog(@"ERROR: interaction controller busy");
        return NO;
    }
    
    NSLog(@"openWithInteractionController: uti=%@, name = %@, url = %@", uti, name, myURL);
    self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:myURL];
    self.interactionController.delegate = self;
    self.interactionController.UTI = uti;
    self.interactionController.name = name;
    self.interactionView = view;
    self.interactionViewController = controller;
    [self.interactionController presentOpenInMenuFromRect:CGRectNull inView:view animated:YES];
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
    self.interactionView = nil;
    self.interactionViewController = nil;
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
    NSLog(@"willBeginSendingToApplication %@", application);
    self.hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"archive_sending_hud_title", nil)];
    [self.hud show];
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    NSLog(@"didEndSendingToApplication %@", application);
    [self.hud dismiss];
    self.interactionView = nil;
    self.interactionViewController = nil;
}


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
                int result = [[UserProfile sharedProfile] importCredentialsJson:credentials];
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
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_transfer_safety_question", nil)
                                                     message: nil
                                             completionBlock: completion
                                           cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                           otherButtonTitles: NSLocalizedString(@"transfer", nil),nil];
    [alert show];
}
/*
- (void)transferArchiveWithHandler:(GenericResultHandler)handler {
    NSURL *archiveURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
    [self makeArchive:archiveURL withHandler:^(NSURL *url) {
        if (url != nil) {
            NSData *data = [NSData dataWithContentsOfURL:url];
            BOOL ok = [[UserProfile sharedProfile]transferArchive:data];
            handler(ok);
        } else {
            handler(NO);
        }
    }];
}
*/

- (void)transferArchiveWithHandler:(GenericResultHandler)handler {
    NSURL *archiveURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
    [self makeArchive:archiveURL withHandler:^(NSURL *url) {
        if (url != nil) {
            UIViewController * vc = [AppDelegate getTopMostViewController];
            BOOL ok = [AppDelegate.instance openWithInteractionController:url withUTI:kHXOTransferArchiveUTI withName:kHXODefaultArchiveName inView:vc.view withController:vc];
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
                    NSString * fullPath = [[theDirectoryURL path] stringByAppendingPathComponent: subpath];
                    //NSLog(@"fullPath=%@",fullPath);
                    
                    if ([fullPath isEqualToString:[zipFileURL path]]) {
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSURL * url = [self makeArchive:archiveURL];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            onReady(url);
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

    // zip ot
    if (error == nil) {
        if (![AppDelegate zipDirectoryAtURL:[self applicationDocumentsDirectory] toZipFile:archiveURL]) {
            NSLog(@"Failed to create archive at URL %@", archiveURL);
            [[NSFileManager defaultManager] removeItemAtURL:archiveURL error:&error];
            return nil;
        }
    }
    return archiveURL;
}


- (void) importArchive:(NSURL*)archiveURL withHandler:(GenericResultHandler)onReady {
    ModalTaskHUD * hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"archive_import_hud_title", nil)];
    [hud show];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        BOOL success = [self extractArchive:archiveURL];
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.title = NSLocalizedString(@"archive_install_hud_title", nil);
            });
            success = [self installArchive];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud dismiss];
            onReady(success);
        });
    });
}

- (BOOL)extractArchive:(NSURL*) archiveURL {
    NSError *error = nil;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    //if (archiveURL == nil) {
    //    archiveURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"archive.zip"];
    //}
    
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

-(BOOL)installArchive {
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
            } else {
                if ([fileMgr fileExistsAtPath:[backupdbURL path]]) {
                    // remove old backup if necessary
                    [fileMgr removeItemAtURL:backupdbURL error:&error];
                    if (error != nil) {
                        NSLog(@"Error removing old database backup at URL %@, error=%@", backupdbURL, error);
                        return NO;
                    } else {
                        NSLog(@"Removed old database backup at URL %@", backupdbURL);
                    }
                }
                // move current db to backup
                [fileMgr moveItemAtURL:dbURL toURL:backupdbURL error:&error];
                if (error != nil) {
                    NSLog(@"Error moving old database from %@ to backup URL %@, error=%@", dbURL, backupdbURL, error);
                    return NO;
                } else {
                    NSLog(@"Move old database from %@ to backup at URL %@", dbURL, backupdbURL);
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
                    return NO;
                } else {
                    NSLog(@"Moved archive database from %@ to current at URL %@", archivedbURL, dbURL);
                }
                
                NSURL *prefURL = [self preferencesURL];
                NSURL *archivePrefURL = [archiveExtractDirURL URLByAppendingPathComponent: @"archived.preferences"];
                NSURL *backupPrefURL = [archiveExtractDirURL URLByAppendingPathComponent: @"backuped.preferences"];
                if (![fileMgr fileExistsAtPath:[archivePrefURL path]]) {
                    NSLog(@"#ERROR: no preferences to install found at archive URL %@", backupPrefURL);
                } else {
                    NSDictionary * defaults = [NSDictionary dictionaryWithContentsOfURL:archivePrefURL];
                    [defaults enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
                        NSLog(@"Setting prefence %@ to %@", key, object);
                        [[HXOUserDefaults standardUserDefaults] setObject:object forKey:key];
                    }];
                    [[HXOUserDefaults standardUserDefaults] synchronize];
                    
                    /*
                    if ([fileMgr fileExistsAtPath:[backupPrefURL path]]) {
                        // remove old backup if necessary
                        [fileMgr removeItemAtURL:backupPrefURL error:&error];
                        if (error != nil) {
                            NSLog(@"Error removing old preferences backup at URL %@, error=%@", backupPrefURL, error);
                            return NO;
                        } else {
                            NSLog(@"Removed old preferences backup at URL %@", backupPrefURL);
                        }
                    }
                    // move current Pref to backup
                    [[HXOUserDefaults standardUserDefaults] synchronize];

                   [fileMgr moveItemAtURL:prefURL toURL:backupPrefURL error:&error];
                    if (error != nil) {
                        NSLog(@"Error moving old preferences from %@ to backup URL %@, error=%@", prefURL, backupPrefURL, error);
                        return NO;
                    } else {
                        NSLog(@"Move old preferences from %@ to backup at URL %@", prefURL, backupPrefURL);
                    }
                    
                    // move archive Pref to current
                    //[fileMgr moveItemAtURL:archivePrefURL toURL:prefURL error:&error];
                    [fileMgr copyItemAtURL:archivePrefURL toURL:prefURL error:&error];
                    if (error != nil) {
                        NSLog(@"Error moving archived preferences from %@ to current URL %@, error=%@", archivePrefURL, prefURL, error);
                        // move database backup back in place
                        [fileMgr moveItemAtURL:backupPrefURL toURL:prefURL error:&error];
                        if (error != nil) {
                            NSLog(@"Error moving back archived preferences from %@ to current URL %@, error=%@", backupPrefURL, prefURL, error);
                        }
                        return NO;
                    } else {
                        [[HXOUserDefaults standardUserDefaults] synchronize];
                        NSLog(@"Moved archive preferences from %@ to current at URL %@", archivePrefURL, prefURL);
                    }
                    */
                    // clear document directory first
                    NSURL * docDir = [self applicationDocumentsDirectory];
                    {
                        NSArray *fileArray = [fileMgr contentsOfDirectoryAtURL:docDir includingPropertiesForKeys:@[] options:0 error:&error];
                        if (error != nil) {
                            NSLog(@"Error gettting content of document directory %@, error=%@", docDir, error);
                            return NO;
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
                                    return NO;
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
                        return NO;
                    }
                    for (NSURL * fileToMove in fileArray)  {
                        NSURL * destURL = [docDir URLByAppendingPathComponent:[fileToMove lastPathComponent]];
                        [fileMgr moveItemAtURL:fileToMove toURL:destURL error:&error];
                        if (error != nil) {
                            NSLog(@"Error moving file %@ to %@, error=%@", fileToMove, destURL, error);
                            return NO;
                        } else {
                            NSLog(@"Moved file %@ to %@", fileToMove, destURL);
                        }
                    }
                    
                    // get the credentials now
                    int result = [UserProfile.sharedProfile importCredentialsWithPassphrase:@"iafnf&/512%2773=!)/%JJNS&&/()JNjnwn"];
                    if (result != -1) {
                        return YES;
                    }
                    
                }
            }
        }
    }
    return NO;
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
                                          cancelButtonTitle:NSLocalizedString(@"ok",nil)
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
        [self showFatalErrorAlertWithMessage: NSLocalizedString(message_tag, nil) withTitle: NSLocalizedString(title_tag, nil)];

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
                    title_tag = @"credentials_and_database_not_deleted_title";
                    message_tag = @"credentials_and_database_not_deleted_message";
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(title_tag,nil)
                                                                    message: NSLocalizedString(message_tag,nil)
                                                            completionBlock: onNotDeleted
                                                          cancelButtonTitle: NSLocalizedString(@"continue",nil)
                                                          otherButtonTitles:nil];
                    [alert show];
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
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"credentials_invalid_title", nil)
                                                    message: [NSString stringWithFormat:NSLocalizedString(@"credentials_invalid_delete_question", nil),info]
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



