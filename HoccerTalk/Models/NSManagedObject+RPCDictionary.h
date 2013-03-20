//
//  NSManagedObject+RPCDictionary.h
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (RPCDictionary)

- (NSMutableDictionary*) rpcDictionary;
- (void) updateWithDictionary: (NSDictionary*) dict;

@end
