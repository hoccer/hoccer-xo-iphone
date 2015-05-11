//
//  KeyChainItem.h
//  HoccerXO
//
//  Created by pavel on 11.05.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyChainItem : NSObject

+ (BOOL)saveData:(NSString *)service account:(NSString *)account data:(id)data;
+ (id)loadData:(NSString *)service account:(NSString *)account;
+ (BOOL)deleteData:(NSString *)service account:(NSString *)account;

- (id)initWithService: (NSString *)service account:(NSString *) account;
- (BOOL)deleteItem;

@property (nonatomic) id data;
@property (readonly) BOOL exists;

@end
