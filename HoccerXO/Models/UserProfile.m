//
//  UserProfile.m
//  HoccerXO
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserProfile.h"
#import "KeychainItemWrapper.h"
#import <ObjCSRP/HCSRP.h>
#import "NSString+RandomString.h"
#import "NSData+HexString.h"
#import "HXOUserDefaults.h"

static UserProfile * profileInstance;

static NSString * const         kHXOAccountIdentifier = @"HXOAccount";
static NSString * const         kHXOSaltIdentifier    = @"HXOSalt";
static const NSUInteger         kHXOPasswordLength    = 23;
static const SRP_HashAlgorithm  kHXOHashAlgorithm     = SRP_SHA256;
static const SRP_NGType         kHXOPrimeAndGenerator = SRP_NG_1024;

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
        [self loadProfile];
    }
    return self;
}

+ (void) initialize {
    profileInstance = [[UserProfile alloc] init];
}

+ (UserProfile*) sharedProfile {
    return profileInstance;
}

- (NSData*) avatar {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAvatar];
}

- (NSString*) avatarURL {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAvatarURL];
}

- (void) setAvatarURL:(NSString *)avatarURL {
    [[HXOUserDefaults standardUserDefaults] setValue: avatarURL forKey: kHXOAvatarURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
}

- (void) loadProfile {
    self.nickName       = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName];
    NSData * avatar     = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAvatar];
    self.status         = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOUserStatus];
    self.phoneNumber    = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOPhoneNumber];
    self.mailAddress    = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOMailAddress];
    self.twitterName    = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOTwitterName];
    self.facebookName   = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOFacebookName];
    self.googlePlusName = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOGooglePlusName];
    self.githubName     = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOGithubName];
    self.avatarImage = [UIImage imageWithData: avatar];
}

- (void) saveProfile {
    NSData * avatar = UIImageJPEGRepresentation(self.avatarImage, 1.0);
    [[HXOUserDefaults standardUserDefaults] setValue: self.nickName       forKey: kHXONickName];
    [[HXOUserDefaults standardUserDefaults] setValue: avatar              forKey: kHXOAvatar];
    [[HXOUserDefaults standardUserDefaults] setValue: self.status         forKey: kHXOUserStatus];
    [[HXOUserDefaults standardUserDefaults] setValue: self.phoneNumber    forKey: kHXOPhoneNumber];
    [[HXOUserDefaults standardUserDefaults] setValue: self.mailAddress    forKey: kHXOMailAddress];
    [[HXOUserDefaults standardUserDefaults] setValue: self.twitterName    forKey: kHXOTwitterName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.facebookName   forKey: kHXOFacebookName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.googlePlusName forKey: kHXOGooglePlusName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.githubName     forKey: kHXOGithubName];
    [[HXOUserDefaults standardUserDefaults] synchronize];
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

- (NSString*) startSrpAuthentication {
    return [[self.srpUser startAuthentication] hexadecimalString];
}

- (NSString*) processSrpChallenge: (NSString*) challenge {
    return [[self.srpUser processChallenge: [NSData dataWithHexadecimalString: self.salt] B: [NSData dataWithHexadecimalString: challenge]] hexadecimalString];
}
- (BOOL) verifySrpSession: (NSString*) HAMK {
    [self.srpUser verifySession: [NSData dataWithHexadecimalString: HAMK]];
    return self.srpUser.isAuthenticated;
}

- (BOOL) isAuthenticated {
    return self.srpUser.isAuthenticated;
}

- (void) deleteCredentials {
    [_accountItem resetKeychainItem];
    [_saltItem resetKeychainItem];
}


@end
