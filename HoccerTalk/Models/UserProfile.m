//
//  UserProfile.m
//  HoccerTalk
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserProfile.h"
#import "KeychainItemWrapper.h"
#import <ObjCSRP/HCSRP.h>
#import "NSString+RandomString.h"
#import "NSData+HexString.h"

static UserProfile * profileInstance;

static NSString * const         kHXOAccountIdentifier = @"HXOAccount";
static NSString * const         kHXOSaltIdentifier    = @"HXOSalt";
static const NSUInteger         kHXOPasswordLength     = 23;
static const SRP_HashAlgorithm  kHXOHashAlgorithm      = SRP_SHA256;
static const SRP_NGType         kHXOPrimeAndGenerator  = SRP_NG_1024;

@interface UserProfile ()
{
    KeychainItemWrapper * _accountItem;
    KeychainItemWrapper * _saltItem;
}

@property (nonatomic,readonly) HCSRPUser * srpUser;

@end

@implementation UserProfile

- (id) init {
    self = [super init];
    if (self != nil) {
        _accountItem = [[KeychainItemWrapper alloc] initWithIdentifier: kHXOAccountIdentifier accessGroup: nil];
        _saltItem = [[KeychainItemWrapper alloc] initWithIdentifier: kHXOSaltIdentifier accessGroup: nil];
    }
    return self;
}

+ (void) initialize {
    profileInstance = [[UserProfile alloc] init];
}

+ (UserProfile*) sharedProfile {
    return profileInstance;
}

- (NSString*) registerClientAndComputeVerifier: (NSString*) clientId {
    [_accountItem setObject: clientId forKey: (__bridge id)(kSecAttrAccount)];
    [_accountItem setObject: [NSString stringWithRandomCharactersOfLength: kHXOPasswordLength] forKey: (__bridge id)(kSecValueData)];
    NSData * salt;
    NSData * verifier;
    [self.srpUser salt: &salt andVerificationKey: &verifier forPassword: self.password];
    [_saltItem setObject: [salt hexadecimalString] forKey: (__bridge id)(kSecValueData)];
    return [verifier hexadecimalString];
}

@synthesize srpUser = _srpUser;
- (HCSRPUser*) srpUser {
    if (_srpUser == nil) {
        _srpUser = [[HCSRPUser alloc] initWithUserName: self.clientId andPassword: self.password
                                         hashAlgorithm: kHXOHashAlgorithm primeAndGenerator:kHXOPrimeAndGenerator];
    }
    return _srpUser;
}
- (BOOL) isRegistered {
    return ! [self.clientId isEqualToString: @""] && ! [self.password isEqualToString: @""] && ! [self.salt isEqualToString: @""];
}

- (NSString*) clientId {
    return [_accountItem objectForKey: (__bridge id)(kSecAttrAccount)];
}

- (NSString*) password {
    return [_accountItem objectForKey: (__bridge id)(kSecValueData)];
}

- (NSString*) salt {
    return [_saltItem objectForKey: (__bridge id)(kSecValueData)];
}

- (void) deleteCredentials {
    [_accountItem resetKeychainItem];
    [_saltItem resetKeychainItem];
}


@end
