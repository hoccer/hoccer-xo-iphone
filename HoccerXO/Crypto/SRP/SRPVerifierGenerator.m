//
//  SRP6VerifierGenerator.m
//  ObjCSRP
//
//  Created by David Siegel on 16.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SRPVerifierGenerator.h"

#import "BigInteger.h"

@interface SRPVerifierGenerator ()
@end

@implementation SRPVerifierGenerator

- (NSData*) generateVerifierWithSalt: (NSData*) salt username: (NSString*) username password: (NSString*) password {
    BigInteger * x = [self xWithSalt: salt username: username password: password];
    BigInteger * v = [_g power: x modulo: _N];
    return [NSData dataWithBigInteger: v];
}

@end
