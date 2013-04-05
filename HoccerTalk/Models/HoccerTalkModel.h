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

+ (NSString*) entityName;

@end
