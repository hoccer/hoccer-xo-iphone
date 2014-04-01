//
//  Crypto.h
//  Hoccer
//
//  Created by Robert Palmer on 17.06.11.
//  Copyright 2011 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


NSData * randomBytes(size_t count);

@interface Crypto : NSObject

+ (NSData *) random256BitKey;
+ (NSData *) random256BitSalt;
+ (NSData *) XOR:(NSData*)a with:(NSData*)b;
+ (NSData *) make256BitKeyFromPassword:(NSString*)password withSalt:(NSData*)salt;
+ (NSData *) calcSymmetricKeyId:(NSData *)myKeyBits withSalt:(NSData *)salt;

@end
