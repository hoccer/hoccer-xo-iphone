//
//  Environment.m
//  HoccerXO
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Environment.h"

#import "HXOUserDefaults.h"
#import "TCMobileProvision.h"

static Environment * sharedEnvironment = nil;

NSString * const kEnvironmentFile = @"Environment";
NSString * const kValidEnvironments = @"_validEnvironments";

@implementation Environment

+ (void) initialize {
    if (self == [Environment class]) {
        sharedEnvironment = [[Environment alloc] init];
    }
}

+ (Environment*) sharedEnvironment {
    return sharedEnvironment;
}

- (id) init {
    self = [super init];
    if (self != nil) {
        NSString * path = [[NSBundle mainBundle] pathForResource: kEnvironmentFile ofType: @"plist"];
        _environment = [NSDictionary dictionaryWithContentsOfFile: path];
    }
    return self;
}

@synthesize talkServer = _talkServer;
- (NSString*) talkServer {
    if (_talkServer == nil) {
        _talkServer = [self getEnvironmentValueForKeySelector: _cmd];
    }
    return _talkServer;
}

@synthesize fileCacheURI = _fileCacheURI;
- (NSString*) fileCacheURI {
    if (_fileCacheURI == nil) {
        _fileCacheURI = [self getEnvironmentValueForKeySelector: _cmd];
    }
    return _fileCacheURI;
}

@synthesize inviteServer = _inviteServer;
- (NSString*) inviteServer {
    if (_inviteServer == nil) {
        _inviteServer = [self getEnvironmentValueForKeySelector: _cmd];
    }
    return _inviteServer;
}

@synthesize certificateFiles = _certificateFiles;
- (NSArray*) certificateFiles {
    if (_certificateFiles == nil) {
        _certificateFiles = [self getEnvironmentValueForKeySelector: _cmd];
    }
    return _certificateFiles;
}

@synthesize currentEnvironment = _currentEnvironment;
- (NSString*) currentEnvironment {
    if (_currentEnvironment == nil) {
        NSString * defaultEnvironment = (NSString*)[[NSBundle mainBundle] objectForInfoDictionaryKey: @"HXODefaultEnvironment"];
        NSString * overrideEnvironment = (NSString*)[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOEnvironment];
        if (overrideEnvironment != nil) {
            _currentEnvironment = overrideEnvironment;
        } else {
            _currentEnvironment = defaultEnvironment;
        }
        NSLog(@"defaultEnvironment=%@, overrideEnvironment=%@, using environment %@",defaultEnvironment, overrideEnvironment,_currentEnvironment);
        NSLog(@"apnsEnvironment=%@", self.apnsEnvironment);
        
        if ([self.validEnvironments indexOfObject: _currentEnvironment] == NSNotFound) {
            NSLog(@"FATAL: environment '%@' is unknown", _currentEnvironment);
            abort();
        }
    }
    return _currentEnvironment;
}

@synthesize apnsEnvironment = _apnsEnvironment;

- (NSString*) apnsEnvironment {
    if (_apnsEnvironment == nil) {
        
        NSString *mobileprovisionPath = [[[NSBundle mainBundle] bundlePath]
                                         stringByAppendingPathComponent:@"embedded.mobileprovision"];
        TCMobileProvision *mobileprovision = [[TCMobileProvision alloc] initWithData:[NSData dataWithContentsOfFile:mobileprovisionPath]];
        NSDictionary *entitlements = mobileprovision.dict[@"Entitlements"];
        _apnsEnvironment = entitlements[@"aps-environment"];
    }
    if (_apnsEnvironment) {
        return _apnsEnvironment;
    }
    return @"unknown";
    // BOOL production = entitlements && apsEnvironment && [apsEnvironment isEqualToString:@"production"];
}

@synthesize validEnvironments = _validEnvironments;
- (NSArray*) validEnvironments {
    if (_validEnvironments == nil) {
        _validEnvironments = _environment[kValidEnvironments];
    }
    return _validEnvironments;
}

- (id) getEnvironmentValueForKeySelector: (SEL) keySelector {
    NSString * key =  NSStringFromSelector(keySelector);
    [self logMissingValueWarnings: key];
    return _environment[key][self.currentEnvironment];
}

- (void) logMissingValueWarnings: (NSString*) key {
    if (_environment[key] == nil) {
        NSLog(@"FATAL: environment has no setting named '%@'", key);
        abort();
    }
    
    for (NSString * environment in self.validEnvironments) {
        if (_environment[key][environment] == nil) {
            if ([environment isEqualToString: self.currentEnvironment]){
                NSLog(@"FATAL: environment key '%@' has no value for environment '%@'", key, environment);
                abort();
            } else {
                NSLog(@"WARNING: environment key '%@' has no value for environment '%@'", key, environment);

            }
        }
    }
}

- (NSString*) suffixedString: (NSString*) string {
    if ([self.currentEnvironment isEqualToString: @"production"]) {
        return string;
    } else {
        return [NSString stringWithFormat: @"%@_%@", string, [self currentEnvironment]];
    }
}

- (NSString*) inviteUrlScheme {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"HXOUrlScheme"];
}

@end
