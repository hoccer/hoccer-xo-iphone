//
//  HTTPServerController.m
//  HoccerXO
//
//  Created by David Siegel on 28.01.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "HTTPServerController.h"

#import "HXOUserDefaults.h"
#import "HTTPServer.h"
#import "MyDAVConnection.h"
#import "DDTTYLogger.h"
#import "AppDelegate.h"

#import "GCDWebUploader.h"
#import "GCDWebServer.h"

#import "GCDWebServerPrivate.h"

@interface HTTPServerController ()

@property (nonatomic,assign) BOOL         isRunning;
@property (nonatomic,assign) BOOL         canRun;
#ifdef USE_OLD_SERVER
@property (nonatomic,strong) HTTPServer * server;
#else
@property (nonatomic,strong) GCDWebUploader* webUploader;
#endif
@property (nonatomic,strong) id           connectionObserver;

@end

@implementation HTTPServerController

- (id) initWithDocumentRoot: (NSString*) documentRoot {
    self = [super init];
    if (self) {
        if ([self.password isEqualToString:@"hoccer-pw"]) {
            [[HXOUserDefaults standardUserDefaults] setValue: [self niceRandomPassword] forKey: kHXOHttpServerPassword];
            [[HXOUserDefaults standardUserDefaults] synchronize];
        }

        [DDLog addLogger: [DDTTYLogger sharedInstance]];
#ifdef USE_OLD_SERVER
        self.server = [[HTTPServer alloc] init];

        [self.server setConnectionClass: [MyDAVConnection class]];
        [self.server setType: @"_webdav._tcp"]; // set bonjour service type
        [self.server setPort: 8899];
        
        //NSLog(@"Setting document root: %@", documentRoot);
        [self.server setDocumentRoot: documentRoot];
        [self.server addObserver: self
                      forKeyPath: @"isRunning"
                         options: NSKeyValueObservingOptionNew
                         context: NULL];
#else
        self.webUploader = [[GCDWebUploader alloc] initWithUploadDirectory:documentRoot];
        
        [self.webUploader addObserver: self
                           forKeyPath: @"isRunning"
                              options: NSKeyValueObservingOptionNew
                              context: NULL];
        [GCDWebServer setLogLevel:kGCDWebServerLoggingLevel_Info];
#endif

        void(^reachablityBlock)(NSNotification*) = ^(NSNotification* note) {
            NSString * ip = self.address;
            BOOL can_run = ip != nil && ip.length > 0;
            if (can_run != self.canRun) {
                if (self.isRunning && ! can_run) {
                    [self stop];
                }
                self.canRun = can_run;
            }
        };
        reachablityBlock(nil);

        self.connectionObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kGCNetworkReachabilityDidChangeNotification
                                                                                    object:nil
                                                                                     queue:[NSOperationQueue mainQueue]
                                                                                usingBlock:reachablityBlock];
    }
    return self;
}

- (void) dealloc {
#ifdef USE_OLD_SERVER
    [self.server removeObserver: self forKeyPath: @"isRunning"];
#else
    [self.webUploader removeObserver: self forKeyPath: @"isRunning"];
#endif
    [[NSNotificationCenter defaultCenter] removeObserver: self.connectionObserver];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#ifdef USE_OLD_SERVER
    if ([object isEqual: self.server] && [keyPath isEqualToString: NSStringFromSelector(@selector(isRunning))]) {
#else
    if ([object isEqual: self.webUploader] && [keyPath isEqualToString: NSStringFromSelector(@selector(isRunning))]) {
#endif
        BOOL running = [change[NSKeyValueChangeNewKey] boolValue];
        self.isRunning = running;
    }
}
- (void) start {
    NSError *error;
#ifdef USE_OLD_SERVER
    if([self.server start:&error]) {
        NSLog(@"Started HTTP Server on port %hu", [self.server listeningPort]);
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    } else {
        NSLog(@"Error starting HTTP Server: %@", error);
    }
#else
    NSMutableDictionary* options = [NSMutableDictionary dictionary];
    [options setObject:@8899 forKey:GCDWebServerOption_Port];
    BOOL bindToLocalhost = NO;
    [options setObject:@(bindToLocalhost) forKey:GCDWebServerOption_BindToLocalhost];
    [options setObject:@"Hoccer File Browser" forKey:GCDWebServerOption_BonjourName];
    NSString * authenticationUser = @"hoccer";
    NSString * authenticationPassword = self.password;
    NSString * authenticationRealm = @"Authenticate user hoccer";
    [options setValue:authenticationRealm forKey:GCDWebServerOption_AuthenticationRealm];
    [options setObject:@{authenticationUser: authenticationPassword} forKey:GCDWebServerOption_AuthenticationAccounts];
    [options setObject:GCDWebServerAuthenticationMethod_DigestAccess forKey:GCDWebServerOption_AuthenticationMethod];
    if ([self.webUploader startWithOptions:options error:NULL]) {
        NSLog(@"Started HTTP Webupload Server on port %lu", (unsigned long)self.webUploader.port);
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    } else {
        NSLog(@"Error starting HTTP Server: %@", error);
    }
    //if([self.webUploader startWithPort:8899 bonjourName:@"uploader"]) {}
#endif
}

- (void) stop {
#ifdef USE_OLD_SERVER
    if (self.server) {
        [self.server stop];
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    }
#else
    if (self.webUploader) {
        [self.webUploader stop];
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    }
#endif
}

- (NSString*) publishedName {
#ifdef USE_OLD_SERVER
    return self.server.publishedName;
#else
    return self.webUploader.bonjourName;
#endif
}

-(BOOL) isRunning {
#ifdef USE_OLD_SERVER
    return self.server.isRunning;
#else
    return self.webUploader.isRunning;
#endif
}

- (NSString*) password {
    return [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
}

- (int) port {
#ifdef USE_OLD_SERVER
    return self.server.listeningPort;
#else
    return (int)self.webUploader.port;
#endif
}

#if TARGET_IPHONE_SIMULATOR
// use any interface (provided by the host) in the simulator
# define HXO_HTTP_INTERFACE AppDelegate.instance.ownIPAddresses.allKeys.firstObject
#else
# define HXO_HTTP_INTERFACE @"en0/ipv4"
#endif

- (NSString*) address {
    return AppDelegate.instance.ownIPAddresses[HXO_HTTP_INTERFACE];
}

- (NSString*) url {
    NSString * address = self.address;
    return address ? [NSString stringWithFormat: @"http://%@:%d/", address, self.port] : nil;
}

-(NSString*)niceRandomPassword {
    NSArray * syllables = @[@"mi",@"ra",@"du",@"mo",@"pa",@"ge",@"da",@"ma",@"ka",@"tu",@"ki",@"so",@"da",@"ne",@"na",@"el",@"im"];
    unsigned long numSyllables = syllables.count;
    NSString * word = [NSString new];
    for (unsigned long i = 0; i < 4;++i) {
        unsigned long randomNumber = abs(rand())%numSyllables;
        NSString * syllable = syllables[randomNumber];
        word = [word stringByAppendingString:syllable];
    }

    unsigned long randomNumber2 = abs(rand())%10000;
    NSString * newPassword = [NSString stringWithFormat:@"%@%lu",word, randomNumber2];
    return newPassword;
}

@end
