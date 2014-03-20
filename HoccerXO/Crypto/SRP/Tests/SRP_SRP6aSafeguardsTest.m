//
//  SRP6aSafeguardsTest.m
//  ObjCSRP
//
//  Created by David Siegel on 18.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "SRPClient.h"
#import "SRPServer.h"
#import "BigInteger.h"

static NSString * const username = @"alice";
static NSString * const password = @"password123";


@interface SRP_SRP6aSafeguardsTest : XCTestCase
{
    DigestSHA256   * _digest;
    SRPParameters * _params;
    NSData         * _salt;
    NSData         * _verifier;
}

@end

@implementation SRP_SRP6aSafeguardsTest

// unfortunately this is called per test. I haven't found a way to run this only once, yet.
// doesn't matter much, though.
- (void) setUp {
    _digest = [DigestSHA256 digest];
    _params = SRP6.CONSTANTS_1024;
    _salt = [SRP saltForDigest: _digest];
    _verifier = [@"2342" dataUsingEncoding: NSUTF8StringEncoding];
}

- (void)testClientInvalidCredentials0 {
    SRPClient * client = [[SRPClient alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [client generateCredentialsWithSalt: _salt username: username password: password];
    NSData * bogusPublicValue = [NSData dataWithBigInteger: [BigInteger bigIntegerWithValue: 0]];
    XCTAssert([client calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void)testClientInvalidCredentialsN {
    SRPClient * client = [[SRPClient alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [client generateCredentialsWithSalt: _salt username: username password: password];
    BigInteger * N = [BigInteger bigIntegerWithBigInteger: _params.N];
    NSData * bogusPublicValue = [NSData dataWithBigInteger: N];
    XCTAssert([client calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void)testClientInvalidCredentialsTwoN {
    SRPClient * client = [[SRPClient alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [client generateCredentialsWithSalt: _salt username: username password: password];
    BigInteger * twoN = [BigInteger bigIntegerWithBigInteger: _params.N];
    BN_mul_word(twoN.n, 2);
    NSData * bogusPublicValue = [NSData dataWithBigInteger: twoN];
    XCTAssert([client calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void)testClientInvalidCredentialsRandN {
    SRPClient * client = [[SRPClient alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [client generateCredentialsWithSalt: _salt username: username password: password];
    BigInteger * randN = [BigInteger bigIntegerWithBigInteger: _params.N];
    BN_mul_word(randN.n, rand());
    NSData * bogusPublicValue = [NSData dataWithBigInteger: randN];
    XCTAssert([client calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void) testServerInvalidCredentials0 {
    SRPServer * server = [[SRPServer alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [server generateCredentialsWithSalt: _salt username: username verifier: _verifier];
    NSData * bogusPublicValue = [NSData dataWithBigInteger: [BigInteger bigIntegerWithValue: 0]];
    XCTAssert([server calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void) testServerInvalidCredentialsN {
    SRPServer * server = [[SRPServer alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [server generateCredentialsWithSalt: _salt username: username verifier: _verifier];
    BigInteger * N = [BigInteger bigIntegerWithBigInteger: _params.N];
    NSData * bogusPublicValue = [NSData dataWithBigInteger: N];
    XCTAssert([server calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void) testServerInvalidCredentialsTwoN {
    SRPServer * server = [[SRPServer alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [server generateCredentialsWithSalt: _salt username: username verifier: _verifier];
    BigInteger * twoN = [BigInteger bigIntegerWithBigInteger: _params.N];
    BN_mul_word(twoN.n, 2);
    NSData * bogusPublicValue = [NSData dataWithBigInteger: twoN];
    XCTAssert([server calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

- (void) testServerInvalidCredentialsRandN {
    SRPServer * server = [[SRPServer alloc] initWithDigest: _digest N: _params.N g: _params.g];
    [server generateCredentialsWithSalt: _salt username: username verifier: _verifier];
    BigInteger * randN = [BigInteger bigIntegerWithBigInteger: _params.N];
    BN_mul_word(randN.n, rand());
    NSData * bogusPublicValue = [NSData dataWithBigInteger: randN];
    XCTAssert([server calculateSecret: bogusPublicValue error: nil] == nil, @"Passing a bogus public value must fail");
}

@end
