//
//  Crypto.m
//  Hoccer
//
//  Created by Robert Palmer on 17.06.11.
//  Copyright 2011 Hoccer GmbH. All rights reserved.
//

#import <CommonCrypto/CommonKeyDerivation.h>

#import "Crypto.h"

// Makes a random 256-bit salt
static NSData * arc4RandomBytes(size_t count) {
    NSMutableData* data = [NSMutableData dataWithLength:count];
    unsigned char * bytes = [data mutableBytes];
    for (int i=0; i<count; i++) {
        bytes[i] = (unsigned char)arc4random();
    }
    return data;
}

static NSData * secRandomBytes(size_t count) {
    NSMutableData* data = [NSMutableData dataWithLength:count];
    int err = SecRandomCopyBytes(kSecRandomDefault, count, [data mutableBytes]);
    if (err != 0) {
        NSLog(@"RandomBytes; RNG error = %d", errno);
    }
    return [data copy];
}

NSData * randomBytes(size_t count) {
    NSData * secBytes = secRandomBytes(count);
    NSData * arc4Bytes = arc4RandomBytes(count);
    
    return [Crypto XOR:secBytes with:arc4Bytes];
}

@implementation Crypto

+ (NSData *) XOR:(NSData*)a with:(NSData*)b {
    if (a.length != b.length) {
        NSLog(@"ERROR: XOR: a.length != b.length");
        return nil;
    }
    const uint8_t *a_bytes = (uint8_t *)[a bytes];
    const uint8_t *b_bytes = (uint8_t *)[b bytes];
    NSMutableData * result = [NSMutableData dataWithLength:a.length];
    uint8_t *result_bytes = (uint8_t *)[result bytes];
    for (int i = 0; i < a.length; ++i) {
        result_bytes[i] = a_bytes[i] ^ b_bytes[i];
    }
    return result;
}

+ (NSData *)random256BitKey {
    return randomBytes(32);
}

+ (NSData *)random256BitSalt {
    return randomBytes(32);
}

+ (NSData*)make256BitKeyFromPassword:(NSString*)password withSalt:(NSData*)salt {
    NSData* myPassData = [password dataUsingEncoding:NSUTF8StringEncoding];
    const int rounds = 10000;
    
    // see CommonKeyDerivation.h
    NSMutableData* keyData = [NSMutableData dataWithLength:32];
    unsigned char * key = [keyData mutableBytes];
    CCKeyDerivationPBKDF(kCCPBKDF2, myPassData.bytes, myPassData.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA256, rounds, key, 32);
    return keyData;
}

+ (NSData *) calcSymmetricKeyId:(NSData *)myKeyBits withSalt:(NSData *)salt{
    if (myKeyBits == nil) {
        NSLog(@"ERROR: calculating key id from nil key");
        NSLog(@"%@",[NSThread callStackSymbols]);
        return nil;
    }
    if (salt == nil) {
        NSLog(@"ERROR: calculating key id from nil salt");
        NSLog(@"%@",[NSThread callStackSymbols]);
        return nil;
    }
    const int rounds = 10000;
    
    NSMutableData* keyIdData = [NSMutableData dataWithLength:32];
    unsigned char * keyId = [keyIdData mutableBytes];
    CCKeyDerivationPBKDF(kCCPBKDF2, myKeyBits.bytes, myKeyBits.length, salt.bytes, salt.length, kCCPRFHmacAlgSHA256, rounds, keyId, 32);
    NSData * myKeyId = [keyIdData subdataWithRange:NSMakeRange(0, 8)];
    return myKeyId;
}

@end



