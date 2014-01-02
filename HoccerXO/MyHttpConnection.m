//
//  MyHttpConnection.m
//  HoccerXO
//
//  Created by PM on 02.01.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MyHTTPConnection.h"
//#import "HTTPDynamicFileResponse.h"
#import "HTTPDataResponse.h"
#import "HTTPLogging.h"
#import "NSString+StringWithData.h"
#import "AppDelegate.h"
#import "HTTPServer.h"
#import "NSString+HTML.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;


@implementation MyHTTPConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	// Use HTTPConnection's filePathForURI method.
	// This method takes the given path (which comes directly from the HTTP request),
	// and converts it to a full path by combining it with the configured document root.
	//
	// It also does cool things for us like support for converting "/" to "/index.html",
	// and security restrictions (ensuring we don't serve documents outside configured document root folder).
	
	NSString *documentRoot = [config documentRoot];

	NSString *filePath;
    if ([path isEqualToString:@"/"]) {
        filePath = documentRoot;
    } else {
        filePath = [self filePathForURI:path];
    }
	
	// Convert to relative path
	
	
	if (![filePath hasPrefix:documentRoot] && ![path isEqualToString:@"/"])
	{
		// Uh oh.
		// HTTPConnection's filePathForURI was supposed to take care of this for us.
		return nil;
	}
	
	// NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];

    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    
    if (exists && isDirectory)
	{
		HTTPLogVerbose(@"%@[%p]: Serving up dynamic content", THIS_FILE, self);
		
		// The index.html file contains several dynamic fields that need to be completed.
		// For example:
		//
		// Computer name: %%COMPUTER_NAME%%
		//
		// We need to replace "%%COMPUTER_NAME%%" with whatever the computer name is.
		// We can accomplish this easily with the HTTPDynamicFileResponse class,
		// which takes a dictionary of replacement key-value pairs,
		// and performs replacements on the fly as it uploads the file.
		
		NSString *computerName = AppDelegate.instance.httpServer.publishedName;
		NSString *currentTime = [[NSDate date] description];
        
        NSString * header = [NSString stringWithFormat:@"Hoccer XO Server<br/>Host:%@ Time:%@<br/>", [computerName stringByEscapingForHTML],[currentTime stringByEscapingForHTML]];
        
        NSString * listing = @"";

        NSFileManager *fM = [NSFileManager defaultManager];
        NSError * error;
        NSArray * fileList = [fM contentsOfDirectoryAtPath:filePath error:&error];
        NSMutableArray *directoryList = [[NSMutableArray alloc] init];
        for(NSString *file in fileList) {
            NSString *path = [filePath stringByAppendingPathComponent:file];
            BOOL isDir = NO;
            [fM fileExistsAtPath:path isDirectory:(&isDir)];
            if(isDir) {
                [directoryList addObject:file];
            }
            NSString * item = [NSString stringWithFormat:@"<a href='%@'>%@</a><br/>",[file stringByEscapingForHTML],[file stringByEscapingForHTML]];
            listing = [listing stringByAppendingString:item];
        }
        
        NSLog(@"%@", directoryList);
        
        NSString * responseString = [NSString stringWithFormat:@"<body>%@%@</body",header,listing];

        NSData * responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        return [[HTTPDataResponse alloc] initWithData:responseData];
	}
	
	return [super httpResponseForMethod:method URI:path];
}

@end
