//
//  SRP6VerifyingClient.h
//  ObjCSRP
//
//  Created by David Siegel on 16.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SRP.h"

@interface SRPClient : SRP

- (NSData*) generateCredentialsWithSalt: (NSData*) salt username: (NSString*) username password: (NSString*) password;
- (NSData*) calculateSecret: (NSData*) serverB error: (NSError**) error;
- (NSData*) calculateVerifier;
- (NSData*) verifyServer: (NSData*) serverM2 error: (NSError**) error;

@end
