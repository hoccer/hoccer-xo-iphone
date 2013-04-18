//
//  CryptoEngine.h
//
//  Created by Pavel Mayer on 17.04.2013
//  Copyright 2013 Hoccer GmbH. All rights reserved.
//
//  Based on RNCryptorEngine by Rob Napier licensed under the MIT License
//


#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>

extern NSString *const kCryptoErrorDomain;

@interface CryptoEngine : NSObject
- (CryptoEngine *)initWithOperation:(CCOperation)operation algorithm:(CCAlgorithm)algorithm options:(CCOptions)options key:(NSData *)key IV:(NSData *)IV error:(NSError **)error;
- (NSData *)addData:(NSData *)data error:(NSError **)error;
- (NSData *)finishWithError:(NSError **)error;
- (NSInteger) calcOutputLengthForInputLength:(NSInteger)length;
@end