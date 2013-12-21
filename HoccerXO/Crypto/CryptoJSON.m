//
//  CryptoJSON.m
//  HoccerXO
//
//  Created by PM on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "CryptoJSON.h"
#import "Crypto.h"
#import "NSData+CommonCrypto.h"
#import "NSData+Base64.h"

@implementation CryptoJSON



+ (NSData *)encryptedContainer:(NSData*)plainText withPassword:(NSString *)password withType:(NSString *)contentType{
    NSData * salt = [Crypto random256BitSalt];
    NSData * key = [Crypto make256BitKeyFromPassword:password withSalt:salt];
    NSError * myError = nil;
    NSData * cipherText = [plainText AES256EncryptedDataUsingKey:key error:&myError];
    if (myError != nil) {
        NSLog(@"CryptoJSON:encryptedContainer: error=%@", myError);
        return nil;
    }
    NSString * cipherTextString = [cipherText asBase64EncodedString];
    NSString * saltString = [salt asBase64EncodedString];
    NSDictionary * container = @{ @"container" : @"AESPBKDF2",
                                  @"contentType" : contentType,
                                  @"salt": saltString,
                                  @"ciphered": cipherTextString};
    NSData * myJsonContainer = [NSJSONSerialization dataWithJSONObject: container options: 0 error: &myError];
    
    if (myError != nil) {
        NSLog(@"CryptoJSON:encryptedContainer: json error=%@", myError);
        return nil;
    }
    return myJsonContainer;
}

+ (NSDictionary *)parseEncryptedContainer:(NSData*)jsonContainer withContentType:(NSString *)contentType{
    NSError * myError = nil;
    
    NSDictionary * container = [NSJSONSerialization JSONObjectWithData: jsonContainer options: 0 error: & myError];
    if (myError != nil) {
        NSLog(@"CryptoJSON:parseEncryptedContainer: json error=%@", myError);
        return nil;
    }
    if (![@"AESPBKDF2" isEqualToString: container[@"container"] ]) {
        NSLog(@"CryptoJSON:parseEncryptedContainer: bad cctyper=%@", container[@"container"]);
        return nil;
    }
    if (![contentType isEqualToString: container[@"contentType"] ]) {
        NSLog(@"CryptoJSON:parseEncryptedContainer: bad contentType=%@", container[@"contentType"]);
        return nil;
    }
    NSString * saltString = container[@"salt"];
    if (!(saltString.length > 0)) {
        NSLog(@"CryptoJSON:parseEncryptedContainer: no salt");
        return nil;
    }
    NSData * salt = [NSData dataWithBase64EncodedString:saltString];
    if (salt.length != 32) {
        NSLog(@"CryptoJSON:parseEncryptedContainer: bad salt");
        return nil;
    }
    return container;
}

+ (NSData *)decryptedContainer:(NSData*)jsonContainer withPassword:(NSString *)password withType:(NSString *)contentType {
    NSError * myError = nil;

    NSDictionary * container = [CryptoJSON parseEncryptedContainer:jsonContainer withContentType:contentType];
    if (container == nil) {
        return nil;
    }
    NSData * salt = [NSData dataWithBase64EncodedString:container[@"salt"]];
    NSString * cipherTextString = container[@"ciphered"];
    NSData * cipherText = [NSData dataWithBase64EncodedString:cipherTextString];
    if (cipherText.length < 16) {
        NSLog(@"CryptoJSON:decryptedContainer: bad ciphertext");
        return nil;
    }
    NSData * key = [Crypto make256BitKeyFromPassword:password withSalt:salt];
    NSData * plainText = [cipherText decryptedAES256DataUsingKey:key error:&myError];
    if (myError != nil) {
        NSLog(@"CryptoJSON:decryptedContainer: decryption error=%@", myError);
        return nil;
    }
    return plainText;
}


@end
