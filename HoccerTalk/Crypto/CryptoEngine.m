//
//  CryptoEngine.m
//
//  Created by Pavel Mayer on 17.04.2013
//  Copyright 2013 Hoccer GmbH. All rights reserved.
//
//  Based on RNCryptorEngine by Rob Napier licensed under the MIT License
//


#import "CryptoEngine.h"

NSString *const kCryptoErrorDomain = @"com.hoccertalk.crypto";

@interface CryptoEngine ()
@property (nonatomic, readonly) CCCryptorRef cryptor;
@property (nonatomic, readonly) NSMutableData *buffer;
@end

@implementation CryptoEngine
@synthesize cryptor = __cryptor;
@synthesize buffer = __buffer;


- (CryptoEngine *)initWithOperation:(CCOperation)operation algorithm:(CCAlgorithm)algorithm options:(CCOptions)options key:(NSData *)key IV:(NSData *)IV error:(NSError **)error;
{
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

  return [buffer subdataWithRange:NSMakeRange(0, dataOutMoved)];
}

@end