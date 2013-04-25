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
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHTAvatar];
}

- (NSString*) avatarURL {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHTAvatarURL];
}

- (void) setAvatarURL:(NSString *)avatarURL {
    [[HXOUserDefaults standardUserDefaults] setValue: avatarURL forKey: kHTAvatarURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
}

- (void) loadProfile {
    self.nickName       = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTNickName];
    NSData * avatar     = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTAvatar];
    self.status         = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTUserStatus];
    self.phoneNumber    = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTPhoneNumber];
    self.mailAddress    = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTMailAddress];
    self.twitterName    = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTTwitterName];
    self.facebookName   = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTFacebookName];
    self.googlePlusName = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTGooglePlusName];
    self.githubName     = [[HXOUserDefaults standardUserDefaults] valueForKey: kHTGithubName];
    self.avatarImage = [UIImage imageWithData: avatar];
}

- (void) saveProfile {
    NSData * avatar = UIImageJPEGRepresentation(self.avatarImage, 1.0);
    [[HXOUserDefaults standardUserDefaults] setValue: self.nickName       forKey: kHTNickName];
    [[HXOUserDefaults standardUserDefaults] setValue: avatar              forKey: kHTAvatar];
    [[HXOUserDefaults standardUserDefaults] setValue: self.status         forKey: kHTUserStatus];
    [[HXOUserDefaults standardUserDefaults] setValue: self.phoneNumber    forKey: kHTPhoneNumber];
    [[HXOUserDefaults standardUserDefaults] setValue: self.mailAddress    forKey: kHTMailAddress];
    [[HXOUserDefaults standardUserDefaults] setValue: self.twitterName    forKey: kHTTwitterName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.facebookName   forKey: kHTFacebookName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.googlePlusName forKey: kHTGooglePlusName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.githubName     forKey: kHTGithubName];
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
