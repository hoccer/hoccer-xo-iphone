//
//  SRP6VerifierGenerator.h
//  ObjCSRP
//
//  Created by David Siegel on 16.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SRP.h"
#import "Digest.h"

@class BigInteger;

@interface SRPVerifierGenerator : SRP

- (NSData*) generateVerifierWithSalt: (NSData*) salt username: (NSString*) username password: (NSString*) password;

@end
