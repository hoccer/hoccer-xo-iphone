//
//  NSManagedObject+RPCDictionary.h
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "HoccerTalkModel.h"

@interface HoccerTalkModel : NSManagedObject

- (NSMutableDictionary*) rpcDictionary;
- (void) updateWithDictionary: (NSDictionary*) dict;
- (void) updateWithDictionary: (NSDictionary*) dict withKeys:(NSDictionary*)keys;

+ (NSString*) entityName;
+ (NSMutableDictionary*) createDictionaryFromObject:(id)object withKeys:(NSDictionary*)keys;
+ (void) updateObject:(id)object withDictionary:(NSDictionary*)dict withKeys:(NSDictionary*)keys;

@end
