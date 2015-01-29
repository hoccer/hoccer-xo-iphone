//
//  HTTPServerController.h
//  HoccerXO
//
//  Created by David Siegel on 28.01.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// Bundles HTTP and WebDAV features into a single controller object. It is
// currently implemented using composition. If need be we also could derive from
// HTTPServer...

@interface HTTPServerController : NSObject

@property (nonatomic,assign)   BOOL       isRunning;
@property (nonatomic,readonly) NSString * publishedName;
@property (nonatomic,readonly) NSString * password;
@property (nonatomic,readonly) int        port;
@property (nonatomic,readonly) NSString * address;
@property (nonatomic,readonly) NSString * url;

- (id) initWithDocumentRoot: (NSString*) root;

- (void) start;
- (void) stop;

@end
