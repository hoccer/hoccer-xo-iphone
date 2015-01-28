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

@interface HTTPServerController ()

@property (nonatomic,strong) HTTPServer * server;

@end

@implementation HTTPServerController

- (id) initWithDocumentRoot: (NSString*) documentRoot {
    self = [super init];
    if (self) {
        [DDLog addLogger: [DDTTYLogger sharedInstance]];

        self.server = [[HTTPServer alloc] init];

        [self.server setConnectionClass: [MyDAVConnection class]];
        [self.server setType:@"_webdav._tcp"]; // set bonjour service type
        [self.server setPort: 8899];
        
        //NSLog(@"Setting document root: %@", documentRoot);
        [self.server setDocumentRoot: documentRoot];
    }
    return self;
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

@end
