//
//  CryptoEngine.m
//
//  Created by Pavel Mayer on 17.04.2013
//  Copyright 2013 Hoccer GmbH. All rights reserved.
//
//  Based on RNCryptorEngine by Rob Napier licensed under the MIT License
//


#import "CryptoEngine.h"
#import "NSData+HexString.h"
#import "HXOUserDefaults.h"

#define CRYPTO_ENGINE_DEBUG ([[self verbosityLevel]isEqualToString:@"trace"])

NSString *const kCryptoErrorDomain = @"com.hoccertalk.crypto";

@interface CryptoEngine ()
@property (nonatomic, readonly) CCCryptorRef cryptor;
@property (nonatomic, readonly) NSMutableData *buffer;
@end

@implementation CryptoEngine
{
    NSString * _verbosityLevel;
}

@synthesize cryptor = __cryptor;
@synthesize buffer = __buffer;


- (NSString *) verbosityLevel {
    if (_verbosityLevel == nil) {
        _verbosityLevel = [[HXOUserDefaults standardUserDefaults] valueForKey: @"cryptoEngineVerbosity"];
    }
    return _verbosityLevel;
}


- (CryptoEngine *)initWithOperation:(CCOperation)operation algorithm:(CCAlgorithm)algorithm options:(CCOptions)options key:(NSData *)key IV:(NSData *)IV error:(NSError **)error;
{
    if (CRYPTO_ENGINE_DEBUG) {NSLog(@"Initializing CryptoEngine with key %@", [key hexadecimalString]);}
    self = [super init];
    if (self) {
        
        CCCryptorStatus
        cryptorStatus = CCCryptorCreate(operation,
                                        algorithm,
                                        options,
                                        key.bytes,
                                        key.length,
                                        IV.bytes,
                                        &__cryptor);
        
        if (cryptorStatus != kCCSuccess || __cryptor == NULL) {
            if (error) {
                *error = [NSError errorWithDomain:kCryptoErrorDomain code:cryptorStatus userInfo:nil];
            }
            self = nil;
            return nil;
        }
        __buffer = [NSMutableData data];
    }
    return self;
}

- (void)dealloc
{
  if (__cryptor) {
    CCCryptorRelease(__cryptor);
  }
}

- (NSData *)addData:(NSData *)data error:(NSError **)error
{
  if (CRYPTO_ENGINE_DEBUG) {NSLog(@"CryptoEngine addData len %d", data.length);}
  NSMutableData *buffer = self.buffer;
  [buffer setLength:CCCryptorGetOutputLength(self.cryptor, [data length], true)]; // We'll reuse the buffer in -finish

  size_t dataOutMoved;
  CCCryptorStatus
      cryptorStatus = CCCryptorUpdate(self.cryptor,       // cryptor
                                      data.bytes,      // dataIn
                                      data.length,     // dataInLength (verified > 0 above)
                                      buffer.mutableBytes,      // dataOut
                                      buffer.length, // dataOutAvailable
                                      &dataOutMoved);   // dataOutMoved

  if (cryptorStatus != kCCSuccess) {
    if (error) {
      *error = [NSError errorWithDomain:kCryptoErrorDomain code:cryptorStatus userInfo:nil];
    }
    return nil;
  }
  if (CRYPTO_ENGINE_DEBUG) {NSLog(@"CryptoEngine addData moved out data len %zd", dataOutMoved);}

  return [buffer subdataWithRange:NSMakeRange(0, dataOutMoved)];
}

- (NSData *)finishWithError:(NSError **)error
{
  NSMutableData *buffer = self.buffer;
  size_t dataOutMoved;
  CCCryptorStatus
      cryptorStatus = CCCryptorFinal(self.cryptor,        // cryptor
                                     buffer.mutableBytes,       // dataOut
                                     buffer.length,  // dataOutAvailable
                                     &dataOutMoved);    // dataOutMoved
  if (cryptorStatus != kCCSuccess) {
    if (error) {
      *error = [NSError errorWithDomain:kCryptoErrorDomain code:cryptorStatus userInfo:nil];
    }
    return nil;
  }
  if (CRYPTO_ENGINE_DEBUG) {NSLog(@"CryptoEngine finish moved out data len %zd", dataOutMoved);}

  return [buffer subdataWithRange:NSMakeRange(0, dataOutMoved)];
}

- (NSInteger) calcOutputLengthForInputLength:(NSInteger)length {
    return CCCryptorGetOutputLength(self.cryptor, length, true);
}


@end