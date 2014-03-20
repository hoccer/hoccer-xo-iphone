//
//  SRP_FuzzyTest.m
//  HoccerXO
//
//  Created by David Siegel on 20.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "SRP6Client.h"
#import "SRP6Server.h"
#import "SRP6VerifierGenerator.h"

#import "NSString+RandomString.h"

@interface SRP_FuzzyTest : XCTestCase
@end


@implementation SRP_FuzzyTest

- (id) randomItem: (NSArray*) array {
    return array[rand() % array.count];
}



- (void)testRandomValids {
    NSArray * parameters = @[SRP6.CONSTANTS_1024, SRP6.CONSTANTS_2048, SRP6.CONSTANTS_4096, SRP6.CONSTANTS_8192];
    NSArray * digests = @[[DigestSHA1 digest], [DigestSHA224 digest], [DigestSHA256 digest], [DigestSHA384 digest], [DigestSHA512 digest]];
    NSArray * users = @[@"alice", @"bob", @"carol", @"dude", @"eve", @"fox", @"george", @"henry"];

    for (unsigned i = 0; i < 20; ++i) {
        id digest = [self randomItem: digests];
        SRP6Parameters * params = [self randomItem: parameters];
        NSString * user = [self randomItem: users];
        NSString * password = [NSString stringWithRandomCharactersOfLength: 23];

        NSData * salt = [SRP6 saltForDigest: digest];

        SRP6VerifierGenerator * generator = [[SRP6VerifierGenerator alloc] initWithDigest: digest N: params.N g: params.g];
        NSData * verifier = [generator generateVerifierWithSalt: salt username: user password: password];

        SRP6Client * client = [[SRP6Client alloc] initWithDigest: digest N: params.N g: params.g];
        SRP6Server * server = [[SRP6Server alloc] initWithDigest: digest N: params.N g: params.g];

        NSData * A = [client generateCredentialsWithSalt: salt username: user password: password];

        NSData * B = [server generateCredentialsWithSalt: salt username: user verifier: verifier];

        NSError * error;
        NSData * serverS = [server calculateSecret: A error: &error];
        XCTAssert(serverS, @"error: %@", error);

        NSData * clientS = [client calculateSecret: B error: &error];
        XCTAssert(clientS, @"error: %@", error);

        XCTAssert([clientS isEqualToData: serverS], @"Client secret must match server secret");

        NSData * M1 = [client calculateVerifier];

        NSData * M2 = [server verifyClient: M1 error: &error];
        XCTAssert(M2, @"error: %@", error);
        
        NSData * sessionKey = [client verifyServer: M2 error: &error];
        XCTAssert(sessionKey, @"error: %@", error);
    }
}

- (void)testRandomInvalids {
    NSArray * parameters = @[SRP6.CONSTANTS_1024, SRP6.CONSTANTS_2048, SRP6.CONSTANTS_4096, SRP6.CONSTANTS_8192];
    NSArray * digests = @[[DigestSHA1 digest], [DigestSHA224 digest], [DigestSHA256 digest], [DigestSHA384 digest], [DigestSHA512 digest]];
    NSArray * users = @[@"alice", @"bob", @"carol", @"dude", @"eve", @"fox", @"george", @"henry"];

    NSString * user = [self randomItem: users];
    NSString * password = [NSString stringWithRandomCharactersOfLength: 23];
    id digest = [self randomItem: digests];
    SRP6Parameters * params = [self randomItem: parameters];

    NSData * salt = [SRP6 saltForDigest: digest];

    SRP6VerifierGenerator * generator = [[SRP6VerifierGenerator alloc] initWithDigest: digest N: params.N g: params.g];
    NSData * verifier = [generator generateVerifierWithSalt: salt username: user password: password];
    SRP6Server * server = [[SRP6Server alloc] initWithDigest: digest N: params.N g: params.g];


    for (unsigned i = 0; i < 1000; ++i) {
        NSString * wrong;

        do {
            wrong = [NSString stringWithRandomCharactersOfLength: 23];
        } while ([wrong isEqualToString: password]);


        SRP6Client * client = [[SRP6Client alloc] initWithDigest: digest N: params.N g: params.g];

        NSData * A = [client generateCredentialsWithSalt: salt username: user password: wrong];

        NSData * B = [server generateCredentialsWithSalt: salt username: user verifier: verifier];

        NSError * error;
        NSData * serverS = [server calculateSecret: A error: &error];
        XCTAssert(serverS, @"error: %@", error);

        NSData * clientS = [client calculateSecret: B error: &error];
        XCTAssert(clientS, @"error: %@", error);

        XCTAssert( ! [clientS isEqualToData: serverS], @"Client secret must match server secret");

        NSData * M1 = [client calculateVerifier];

        NSData * M2 = [server verifyClient: M1 error: &error];
        XCTAssert( ! M2, @"Client verification must fail");

        NSData * sessionKey = [client verifyServer: M2 error: &error];
        XCTAssert( ! sessionKey, @"Server verification must fail");
    }
}

@end
