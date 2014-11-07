//
//  MyDAVConnection.m
//  HoccerXO
//
//  Created by pavel on 07/11/14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MyDAVConnection.h"
#import "HTTPLogging.h"
#import "HXOUserDefaults.h"

#ifdef WITH_WEBSERVER
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;
#endif

@implementation MyDAVConnection

#if 0
- (BOOL)isPasswordProtected:(NSString *)path
{
    // We're only going to password protect the "secret" directory.
    //BOOL result = [path hasPrefix:@"/secret"];
    //HTTPLogTrace2(@"%@[%p]: isPasswordProtected(%@) - %@", THIS_FILE, self, path, (result ? @"YES" : @"NO"));
    //return result;
    return YES;
}

- (BOOL)useDigestAccessAuthentication
{
    HTTPLogTrace();
    
    // Digest access authentication is the default setting.
    // Notice in Safari that when you're prompted for your password,
    // Safari tells you "Your login information will be sent securely."
    //
    // If you return NO in this method, the HTTP server will use
    // basic authentication. Try it and you'll see that Safari
    // will tell you "Your password will be sent unencrypted",
    // which is strongly discouraged.
    
    return YES;
}

- (NSString *)passwordForUser:(NSString *)username
{
    HTTPLogTrace();
    
    // You can do all kinds of cool stuff here.
    // For simplicity, we're not going to check the username, only the password.
    // return @"secret";
    return [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
}

- (NSString *)realm
{
    HTTPLogTrace();
    
    // Override me to provide a custom realm...
    // You can configure it for the entire server, or based on the current request
    
    return @"Hoccer WebServer on Client App";
}
#endif

@end
