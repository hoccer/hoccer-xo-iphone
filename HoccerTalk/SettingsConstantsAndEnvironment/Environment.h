//
//  Environment.h
//  HoccerTalk
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Environment : NSObject
{
    NSDictionary * _environment;
}

+ (Environment*) sharedEnvironment;

@property (nonatomic, readonly) NSString * currentEnvironment;
@property (nonatomic, readonly) NSArray  * validEnvironments;

@property (nonatomic, readonly) NSString * talkServer;
@property (nonatomic, readonly) NSString * fileCacheURI;

@end
