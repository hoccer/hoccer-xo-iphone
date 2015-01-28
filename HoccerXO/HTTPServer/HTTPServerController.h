//
//  HTTPServerController.h
//  HoccerXO
//
//  Created by David Siegel on 28.01.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTTPServerController : NSObject

@property (nonatomic,assign) BOOL isRunning;
@property (nonatomic,readonly) NSString * publishedName;
@property (nonatomic,readonly) NSString * password;
@property (nonatomic,readonly) int port;

- (id) initWithDocumentRoot: (NSString*) root;

- (void) start;
- (void) stop;

@end
