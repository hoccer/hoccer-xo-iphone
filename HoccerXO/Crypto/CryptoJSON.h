//
//  CryptoJSON.h
//  HoccerXO
//
//  Created by PM on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CryptoJSON : NSObject

+ (NSData *)encryptedContainer:(NSData*)plainText withPassword:(NSString *)password withType:(NSString *)contentType;
+ (NSData *)decryptedContainer:(NSData*)jsonContainer withPassword:(NSString *)password withType:(NSString *)contentType;
+ (NSDictionary *)parseEncryptedContainer:(NSData*)jsonContainer withContentType:(NSString *)contentType;

@end
