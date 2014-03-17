//
//  SRP6.h
//  ObjCSRP
//
//  Created by David Siegel on 16.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SRP6Parameters.h"
#import "Digest.h"

@interface SRP6 : NSObject
{
    id<SRPDigest> _digest;
    BigInteger *  _N;
    BigInteger *  _g;
}

- (id) initWithDigest: (id<SRPDigest>) digest N: (BigInteger*) N g: (BigInteger*) g;
- (BigInteger*) selectPrivateValue;
- (BigInteger*) xWithSalt: (NSData*) salt username: (NSString*) username password: (NSString*) password;
- (BigInteger*) k;
- (BigInteger*) uWithA: (BigInteger*) A andB: (BigInteger*) B;

-

+ (SRP6Parameters*) CONSTANTS_1024;
+ (SRP6Parameters*) CONSTANTS_2048;
+ (SRP6Parameters*) CONSTANTS_4096;
+ (SRP6Parameters*) CONSTANTS_8192;

@end
