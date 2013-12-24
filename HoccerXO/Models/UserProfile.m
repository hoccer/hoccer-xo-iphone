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
#import "NSString+StringWithData.h"
#import "HXOUserDefaults.h"
#import "Environment.h"
#import "NSString+UUID.h"
#import "AppDelegate.h"
#import "CryptoJSON.h"
#import "ProfileViewController.h"

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

@dynamic groupMembershipList;

- (id) init {
    self = [super init];
    if (self != nil) {
        _accountItem = [[KeychainItemWrapper alloc] initWithIdentifier: [[Environment sharedEnvironment] suffixedString: kHXOAccountIdentifier] accessGroup: nil];
        _saltItem = [[KeychainItemWrapper alloc] initWithIdentifier: [[Environment sharedEnvironment] suffixedString: kHXOSaltIdentifier] accessGroup: nil];
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

- (NSString*) avatarUploadURL {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAvatarUploadURL];
}

- (void) setAvatarUploadURL:(NSString *)avatarURL {
    [[HXOUserDefaults standardUserDefaults] setValue: avatarURL forKey: kHXOAvatarUploadURL];
    [[HXOUserDefaults standardUserDefaults] synchronize];
}

- (void) loadProfile {
    self.nickName       = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName];
    /*
    if (!self.nickName.length > 0) { // TODO: fix crash on editing start when nickname empty
        [[HXOUserDefaults standardUserDefaults] setValue: @"???"       forKey: kHXONickName];
        self.nickName       = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName];
    }
     */
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
    float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
    NSData * avatar = UIImageJPEGRepresentation(self.avatarImage, photoQualityCompressionSetting/10.0);
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

- (NSString*)groupMembershipList {
    return @"n/a"; //TODO: return something more interesting
}

- (NSString*) registerClientAndComputeVerifier: (NSString*) clientId {
    [_accountItem setObject: clientId forKey: (__bridge id)(kSecAttrAccount)];
    [_accountItem setObject: [NSString stringWithRandomCharactersOfLength: kHXOPasswordLength] forKey: (__bridge id)(kSecValueData)];
    NSData * salt;
    NSData * verifier;
    [self.srpUser salt: &salt andVerificationKey: &verifier forPassword: self.password];
    // XXX Workaround for keychain item issue:
    // first keychain claims there is no such item. Later it complains it can not create such
    // an item because it already exists. Using a unique identifier in kSecAttrAccount helps...
    NSString * keychainItemBugWorkaround = [NSString stringWithUUID];
    [_saltItem setObject: keychainItemBugWorkaround forKey: (__bridge id)(kSecAttrAccount)]; 
    [_saltItem setObject: [salt hexadecimalString] forKey: (__bridge id)(kSecValueData)];
    [ProfileViewController exportCredentials];
    return [verifier hexadecimalString];
}
    
-  (NSDictionary *) extractCredentials {
    NSDictionary * credentials = @{ @"password": [self password],
                                    @"salt" :[self salt],
                                    @"clientId" : self.clientId };
    return credentials;
}

- (BOOL) sameCredentialsInDict:(NSDictionary*)credentials {
    NSDictionary * currentCredentials = [self extractCredentials];
    return  [credentials[@"password"] isEqualToString:currentCredentials[@"password"]] &&
            [credentials[@"salt"] isEqualToString:currentCredentials[@"salt"]] &&
            [credentials[@"clientId"] isEqualToString:currentCredentials[@"clientId"]];
}


- (void) setCredentialsWithDict:(NSDictionary*)credentials {
    [_accountItem setObject: credentials[@"clientId"] forKey: (__bridge id)(kSecAttrAccount)];
    [_accountItem setObject: credentials[@"password"] forKey: (__bridge id)(kSecValueData)];
    NSString * keychainItemBugWorkaround = [NSString stringWithUUID];
    [_saltItem setObject: keychainItemBugWorkaround forKey: (__bridge id)(kSecAttrAccount)];
    [_saltItem setObject: credentials[@"salt"] forKey: (__bridge id)(kSecValueData)];
}
    
-(NSURL*)getCredentialsURL {
    NSString *newFileName = @"credentials.json";
    NSURL * appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
    NSString * myDocDir = [appDocDir path];
    NSString * savePath = [myDocDir stringByAppendingPathComponent: newFileName];
    NSURL * myLocalURL = [NSURL fileURLWithPath:savePath];
    return myLocalURL;
}
    
- (void)exportCredentialsWithPassphrase:(NSString*)passphrase {
    NSURL * myLocalURL = [self getCredentialsURL];

    NSDictionary * json = [self extractCredentials];
    NSError * error;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject: json options: 0 error: &error];
    if ( jsonData == nil) {
        NSLog(@"failed to extract credentials: %@", error);
        return;
    }
    NSData * cryptedJsonData = [CryptoJSON encryptedContainer:jsonData withPassword:passphrase withType:@"credentials"];
    
    [cryptedJsonData writeToURL:myLocalURL atomically:NO];
    NSLog(@"Exported credentials to %@", myLocalURL);
    NSLog(@"Credentials: %@", [NSString stringWithData:jsonData usingEncoding:NSUTF8StringEncoding]);
    NSLog(@"Crypted Credentials: %@", [NSString stringWithData:cryptedJsonData usingEncoding:NSUTF8StringEncoding]);
}

- (BOOL) foundCredentialsFile {
    NSURL * url = [self getCredentialsURL];
    NSDictionary * credentials = nil;
    NSData * cryptedJsonCredentials = nil;
    @try {
        cryptedJsonCredentials = [NSData dataWithContentsOfURL: url];
        if (cryptedJsonCredentials == nil) {
            return NO;
        }
        credentials = [CryptoJSON parseEncryptedContainer:cryptedJsonCredentials withContentType:@"credentials"];
    } @catch (NSException * ex) {
        NSLog(@"ERROR parsing credentials, cryptedJsonCredentials = %@, ex=%@, contentURL=%@", cryptedJsonCredentials, ex, url);
        return NO;
    }
    return credentials != nil;
}

- (BOOL) deleteCredentialsFile {
    NSError * myError = nil;
    NSURL * url = [self getCredentialsURL];
    [[NSFileManager defaultManager] removeItemAtURL:url error:&myError];
    return myError == nil;
}


- (NSDictionary*) loadCredentialsWithPassphrase:(NSString*)passphrase {
    NSURL * url = [self getCredentialsURL];
    NSError * error = nil;
    NSDictionary * credentials = nil;
    NSData * jsonCredentials = nil;
    NSData * cryptedJsonCredentials = nil;
    @try {
        cryptedJsonCredentials = [NSData dataWithContentsOfURL: url];
        if (cryptedJsonCredentials == nil) {
            return nil;
        }
        jsonCredentials = [CryptoJSON decryptedContainer:cryptedJsonCredentials withPassword:passphrase withType:@"credentials"];
        if (jsonCredentials == nil) {
            NSLog(@"failed to decrypt credentials: %@", error);
            return nil;
        }
        credentials = [NSJSONSerialization JSONObjectWithData: jsonCredentials options: 0 error: & error];
    } @catch (NSException * ex) {
        NSLog(@"ERROR parsing credentials, jsonCredentials = %@, ex=%@, contentURL=%@", jsonCredentials, ex, url);
        return nil;
    }
    if (credentials[@"clientId"] == nil ||  credentials[@"password"] == nil || credentials[@"salt"] == nil) {
        NSLog(@"ERROR: missing field in jsonCredentials = %@", credentials);
        return nil;
    }
    return credentials;
}
    
- (int) importCredentialsWithPassphrase:(NSString*)passphrase {
    NSDictionary * credentials = [self loadCredentialsWithPassphrase:passphrase];
    if (credentials != nil) {
        if (![self sameCredentialsInDict:credentials]) {
            [self setCredentialsWithDict:credentials];
            return 1;
        }
        return 0;
    }
    return -1;
}

+(NSURL*)getKeyFileURLWithKeyTypeName:(NSString*)keyTypeName forUser:(NSString*)userName withKeyId:(NSString*)keyId {
    NSString *newFileName = [NSString stringWithFormat:@"%@-%@-%@.pem",keyTypeName,userName,keyId];
    newFileName = [AppDelegate sanitizeFileNameString:newFileName];
    NSURL * appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
    NSString * myDocDir = [appDocDir path];
    NSString * savePath = [myDocDir stringByAppendingPathComponent: newFileName];
    NSURL * myLocalURL = [NSURL fileURLWithPath:savePath];
    return myLocalURL;
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
