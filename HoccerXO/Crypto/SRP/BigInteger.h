//
//  BigInteger.h
//  ObjCSRP
//
//  Created by David Siegel on 16.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


#import <openssl/bn.h>

@interface BigInteger : NSObject

- (id) initWithString: (NSString*) string radix: (int) radix;

- (BOOL) isEqualToBigInt: (BigInteger*) other;
- (BOOL) isZero;

@property (nonatomic,readonly) BIGNUM * n;
@property (nonatomic,readonly) NSUInteger length;

+ (BigInteger*) bigInteger;
+ (BigInteger*) bigIntegerWithBigInteger: (BigInteger*) other;
+ (BigInteger*) bigIntegerWithBIGNUM: (BIGNUM*) bn;
+ (BigInteger*) bigIntegerWithString: (NSString*) string radix: (int) radix;
+ (BigInteger*) bigIntegerWithData: (NSData*) data;
+ (BigInteger*) bigIntegerWithValue: (NSInteger) value;

- (BigInteger*) times:  (BigInteger*) f;
- (BigInteger*) plus:   (BigInteger*) b;
- (BigInteger*) modulo: (BigInteger*) m;

- (BigInteger*) times: (BigInteger*) f modulo: (BigInteger*) m;
- (BigInteger*) power: (BigInteger*) y modulo: (BigInteger*) m;
- (BigInteger*) plus:  (BigInteger*) b modulo: (BigInteger*) m;
- (BigInteger*) minus: (BigInteger*) b modulo: (BigInteger*) m;

@end

@interface NSData (BigInteger)

+ (NSData*) dataWithBigInteger: (BigInteger*) a;
+ (NSData*) dataWithBigInteger: (BigInteger*) a leftPaddedToLength: (NSUInteger) length;

@end
