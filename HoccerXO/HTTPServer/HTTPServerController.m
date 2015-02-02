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

@interface HTTPServerController ()

@property (nonatomic,assign) BOOL         isRunning;
@property (nonatomic,assign) BOOL         canRun;
@property (nonatomic,strong) HTTPServer * server;

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

        void(^reachablityBlock)(NSNotification*) = ^(NSNotification* note) {
            NSString * ip = self.address;
            BOOL can_run = ip != nil && ip.length > 0;
            if (can_run != self.canRun) {
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
    [self.server removeObserver: self forKeyPath: @"isRunning"];
    [[NSNotificationCenter defaultCenter] removeObserver: self.connectionObserver];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: self.server] && [keyPath isEqualToString: NSStringFromSelector(@selector(isRunning))]) {
        BOOL running = [change[NSKeyValueChangeNewKey] boolValue];
        self.isRunning = running;
    }
}
- (void) start {
    NSError *error;
    if([self.server start:&error]) {
        NSLog(@"Started HTTP Server on port %hu", [self.server listeningPort]);
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    } else {
        NSLog(@"Error starting HTTP Server: %@", error);
    }
}

- (void) stop {
    if (self.server) {
        [self.server stop];
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    }
}

- (NSString*) publishedName {
    return self.server.publishedName;
}

-(BOOL) isRunning {
    return self.server.isRunning;
}

- (NSString*) password {
    return [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
}

- (int) port {
    return self.server.listeningPort;
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
    return [NSString stringWithFormat: @"http://%@:%d/", self.address, self.port];
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
