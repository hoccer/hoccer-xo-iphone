//
//  UserProfile.m
//  HoccerXO
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserProfile.h"
#import "KeychainItemWrapper.h"
#import "NSString+RandomString.h"
#import "NSData+HexString.h"
#import "NSString+StringWithData.h"
#import "HXOUserDefaults.h"
#import "Environment.h"
#import "NSString+UUID.h"
#import "AppDelegate.h"
#import "CryptoJSON.h"
#import "SRPClient.h"
#import "SRPVerifierGenerator.h"
#import "CCRSA.h"

static UserProfile * profileInstance;

static NSString * const kHXOAccountIdentifier = @"HXOAccount";
static NSString * const kHXOSaltIdentifier    = @"HXOSalt";
static const NSUInteger kHXOPasswordLength    = 23;

const NSUInteger kHXODefaultKeySize    = 2048;

@interface UserProfile ()
{
    KeychainItemWrapper * _accountItem;
    KeychainItemWrapper * _saltItem;
    UIImage * _avatarImage;
    unsigned int _avatarImageVersion;
    unsigned int _savedAvatarImageVersion;
}

@property (nonatomic,readonly) SRPClient * srpClient;

@end

@implementation UserProfile

@dynamic groupMembershipList;
@synthesize connectionStatus;
@synthesize deletedObject;
@dynamic avatarImage;
@dynamic keyLength;

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
    if (self == [UserProfile class]) {
        profileInstance = [[UserProfile alloc] init];
    }
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

- (UIImage *) avatarImage {
    return _avatarImage;
}

- (void) setAvatarImage:(UIImage *)newAvatarImage {
    _avatarImage = newAvatarImage;
    _avatarImageVersion++;
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
    self.avatarImage = [UIImage imageWithData: avatar];
    _savedAvatarImageVersion = 0;
    _avatarImageVersion = 0;
}

- (void) saveProfile {
    
    NSMutableDictionary * itemsChanged = [NSMutableDictionary new];
    if (_avatarImageVersion != _savedAvatarImageVersion) {
        float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
        NSData * avatar = UIImageJPEGRepresentation(self.avatarImage, photoQualityCompressionSetting/10.0);
        [[HXOUserDefaults standardUserDefaults] setValue: avatar              forKey: kHXOAvatar];
        itemsChanged[kHXOAvatar] = @YES;
        _savedAvatarImageVersion = _avatarImageVersion;
    }
    
    
    if (![self.nickName isEqualToString:[[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName]]) {
        itemsChanged[kHXONickName] = @YES;
    }
    NSString * oldStatus = [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOUserStatus];
    if (self.status != nil || self.status != oldStatus) {
        if (![self.status isEqualToString:oldStatus]) {
            itemsChanged[kHXOUserStatus] = @YES;
        }
    }
    
    [[HXOUserDefaults standardUserDefaults] setValue: self.nickName       forKey: kHXONickName];
    [[HXOUserDefaults standardUserDefaults] setValue: self.status         forKey: kHXOUserStatus];
    [[HXOUserDefaults standardUserDefaults] synchronize];

    id userInfo = @{ @"itemsChanged":itemsChanged};
    NSLog(@"profileUpdatedByUser info %@",userInfo);
    NSNotification *notification = [NSNotification notificationWithName:@"profileUpdatedByUser" object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
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


- (id<SRPDigest>) srpDigest {
    return [DigestSHA256 digest];
}

- (SRPParameters*) srpParameters {
    return SRP.CONSTANTS_1024;
}

- (NSString*) registerClientAndComputeVerifier: (NSString*) clientId {
    [_accountItem setObject: clientId forKey: (__bridge id)(kSecAttrAccount)];
    [_accountItem setObject: [NSString stringWithRandomCharactersOfLength: kHXOPasswordLength] forKey: (__bridge id)(kSecValueData)];
    SRPParameters * params = [self srpParameters];
    id<SRPDigest> digest = [self srpDigest];
    NSData * salt = [SRP saltForDigest: digest];
    SRPVerifierGenerator * verifierGenerator = [[SRPVerifierGenerator alloc] initWithDigest: digest N: params.N g: params.g];
    NSData * verifier = [verifierGenerator generateVerifierWithSalt: salt username: self.clientId password: self.password];
    // XXX Workaround for keychain item issue:
    // first keychain claims there is no such item. Later it complains it can not create such
    // an item because it already exists. Using a unique identifier in kSecAttrAccount helps...
    NSString * keychainItemBugWorkaround = [NSString stringWithUUID];
    [_saltItem setObject: keychainItemBugWorkaround forKey: (__bridge id)(kSecAttrAccount)]; 
    [_saltItem setObject: [salt hexadecimalString] forKey: (__bridge id)(kSecValueData)];
    //[ProfileViewController exportCredentials];
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

- (NSData*)encryptCredentialsWithPassphrase:(NSString*)passphrase {
    NSDictionary * json = [self extractCredentials];
    NSError * error;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject: json options: 0 error: &error];
    if ( jsonData == nil) {
        NSLog(@"failed to extract credentials: %@", error);
        return nil;
    }
    // NSLog(@"Credentials: %@", [NSString stringWithData:jsonData usingEncoding:NSUTF8StringEncoding]);
    NSData * cryptedJsonData = [CryptoJSON encryptedContainer:jsonData withPassword:passphrase withType:@"credentials"];
    NSLog(@"Crypted Credentials: %@", [NSString stringWithData:cryptedJsonData usingEncoding:NSUTF8StringEncoding]);
    return cryptedJsonData;
}


- (NSDictionary*) decryptedCredentials:(NSData*)cryptedJsonCredentials withPassphrase:(NSString*)passphrase {
    NSError * error = nil;
    NSData * jsonCredentials = nil;
    @try {
        if (cryptedJsonCredentials == nil) {
            return nil;
        }
        jsonCredentials = [CryptoJSON decryptedContainer:cryptedJsonCredentials withPassword:passphrase withType:@"credentials"];
        if (jsonCredentials == nil) {
            NSLog(@"failed to decrypt credentials: %@", error);
            return nil;
        }
    } @catch (NSException * ex) {
        NSLog(@"ERROR parsing credentials, jsonCredentials = %@, ex=%@", jsonCredentials, ex);
        return nil;
    }
    return [self parseCredentials:jsonCredentials];
}

-(NSString*)credentialsSetting {
    return [self credentialsSettingWithId:@""];
}

-(NSString*)credentialsSettingWithId:(NSString*)myId {
    return [[Environment sharedEnvironment] suffixedString: [@"cryptedCredentials" stringByAppendingString:myId] ];
}

- (NSData*) credentialsBackup {
    return [HXOUserDefaults.standardUserDefaults valueForKey:self.credentialsSetting];
}

- (NSData*) credentialsBackupWithId:(NSString*)myId {
    return [HXOUserDefaults.standardUserDefaults valueForKey:[self credentialsSettingWithId:myId]];
}

- (BOOL) foundCredentialsBackup {
    return [self credentialsBackup] != nil;
}

-(void)backupCredentials {
    [self backupCredentialsWithId: @""];
}

-(void)backupCredentialsWithId:(NSString*)myId {
    if (!self.isRegistered) {
        NSLog(@"Not registered, not backing up credentials");
        return;
    }
    NSData * cryptedJsonData = [self encryptCredentialsWithPassphrase:@"Batldfh§$cx%&/()dgsGhajau"];
    if (cryptedJsonData != nil) {
        [[HXOUserDefaults standardUserDefaults] setValue: cryptedJsonData forKey: [self credentialsSettingWithId:myId]];
        [[HXOUserDefaults standardUserDefaults] synchronize];
        NSLog(@"backed up credentials");
    }
}

-(NSDictionary*)restoredCredentialsWithId:(NSString*)myId {
    NSDictionary * credentials = [self decryptedCredentials:[self credentialsBackupWithId:myId] withPassphrase:@"Batldfh§$cx%&/()dgsGhajau"];
    return credentials;
}

-(NSDictionary*)restoredCredentials:(NSString*)myId {
    return [self restoredCredentialsWithId:myId];
}

-(int)restoreCredentials {
    return [self restoreCredentialsWithId:@""];
}

-(int)restoreCredentialsWithId:(NSString*)myId {
    return [self importCredentials:[self restoredCredentialsWithId:myId]];
}

-(void)removeCredentialsBackupWithId:(NSString*)myId {
    NSString * key = [self credentialsSettingWithId:myId];
    if ([[HXOUserDefaults standardUserDefaults] valueForKey:key] != nil) {
        [[HXOUserDefaults standardUserDefaults] removeObjectForKey: key];
        [[HXOUserDefaults standardUserDefaults] synchronize];
    }
}

-(void)verfierChangePlease {
    [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:@"changeVerifier"]];
    [[HXOUserDefaults standardUserDefaults] synchronize];
}

-(void)verfierChangeDone {
    [[HXOUserDefaults standardUserDefaults] setBool: NO forKey: [[Environment sharedEnvironment] suffixedString:@"changeVerifier"]];
    [[HXOUserDefaults standardUserDefaults] synchronize];
}

-(BOOL)verfierChangeRequested {
    return [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:@"changeVerifier"]];
}

- (void)exportCredentialsWithPassphrase:(NSString*)passphrase {
    if (!self.isRegistered) {
        NSLog(@"Not registered, not exporting credentials");
        return;
    }
    NSURL * myLocalURL = [self getCredentialsURL];
    
    NSData * cryptedJsonData = [self encryptCredentialsWithPassphrase:passphrase];
    if (cryptedJsonData != nil) {
        [cryptedJsonData writeToURL:myLocalURL atomically:NO];
        NSLog(@"Exported credentials to %@", myLocalURL);
    }
}

- (BOOL)transferCredentials {
    if (!self.isRegistered) {
        NSLog(@"Not registered, not transfering credentials");
        return NO;
    }
    NSDictionary * json = [self extractCredentials];
    NSError * error;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject: json options: 0 error: &error];
    if ( jsonData == nil) {
        NSLog(@"failed to extract credentials: %@", error);
        return NO;
    }
    
    NSString * credentialsString = [jsonData hexadecimalString];
    NSLog(@"Credentials: %@", credentialsString);
    
    NSString * credentialsUrlString = [NSString stringWithFormat:@"%@://%@", kHXOTransferCredentialsURLImportScheme,credentialsString];
    
    NSURL * myUrl = [NSURL URLWithString:credentialsUrlString];
    NSLog(@"Credentials URL: %@", myUrl);
    
    if ([[UIApplication sharedApplication] openURL:myUrl]) {
        NSLog(@"Credentials openURL returned true");
        return YES;
    } else {
        NSLog(@"Credentials openURL returned false");
        return NO;
    }
    
}

- (NSDictionary*)parseCredentials:(NSData *)jsonCredentials {
    NSError * error = nil;
    NSDictionary * credentials = nil;
    @try {
         credentials = [NSJSONSerialization JSONObjectWithData: jsonCredentials options: 0 error: & error];
    } @catch (NSException * ex) {
        NSLog(@"ERROR parsing credentials, jsonCredentials = %@, ex=%@", jsonCredentials, ex);
        return nil;
    }
    if (credentials[@"clientId"] == nil ||  credentials[@"password"] == nil || credentials[@"salt"] == nil) {
        NSLog(@"ERROR: missing field in jsonCredentials = %@", credentials);
        return nil;
    }
    return credentials;
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

- (NSURL*)fetchCredentialsURL {
    NSString * urlString = [NSString stringWithFormat:@"%@://fetch/", kHXOTransferCredentialsURLExportScheme];
    
    NSURL * myUrl = [NSURL URLWithString:urlString];
    return myUrl;
    
}

- (BOOL) foundCredentialsProviderApp {
#ifdef HOCCER_CLASSIC
    return [[UIApplication sharedApplication] canOpenURL:[self fetchCredentialsURL]];
#else
    return NO;
#endif
}

- (BOOL) deleteCredentialsFile {
    NSError * myError = nil;
    NSURL * url = [self getCredentialsURL];
    [[NSFileManager defaultManager] removeItemAtURL:url error:&myError];
    return myError == nil;
}


- (NSDictionary*) loadCredentialsWithPassphrase:(NSString*)passphrase {
    NSURL * url = [self getCredentialsURL];
    NSData * jsonCredentials = nil;
    NSData * cryptedJsonCredentials = nil;
    @try {
        cryptedJsonCredentials = [NSData dataWithContentsOfURL: url];
        if (cryptedJsonCredentials != nil) {
            return [self decryptedCredentials:cryptedJsonCredentials withPassphrase:passphrase];
        }
    } @catch (NSException * ex) {
        NSLog(@"ERROR parsing credentials, jsonCredentials = %@, ex=%@, contentURL=%@", jsonCredentials, ex, url);
        return nil;
    }
    return nil;
}
    
- (int) importCredentials:(NSDictionary*)credentials {
    if (credentials != nil) {
        if (![self sameCredentialsInDict:credentials]) {
            [self setCredentialsWithDict:credentials];
            return 1;
        }
        return 0;
    }
    return -1;
}

- (int) importCredentialsWithPassphrase:(NSString*)passphrase {
    NSDictionary * credentials = [self loadCredentialsWithPassphrase:passphrase];
    return [self importCredentials:credentials];
}

- (int)importCredentialsJson:(NSData*)jsonData {
    NSDictionary * credentials = [self parseCredentials:jsonData];
    return [self importCredentials:credentials];
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

@synthesize srpClient = _srpClient;
- (SRPClient*) srpClient {
    if (_srpClient == nil) {
        DigestSHA256 * digest = [DigestSHA256 digest];
        SRPParameters * params = SRP.CONSTANTS_1024;
        _srpClient = [[SRPClient alloc] initWithDigest: digest N: params.N g: params.g];
    }
    return _srpClient;
}

- (BOOL) isRegistered {
    NSLog(@"isRegistered: clientId=%@, password=%@, salt=%@",self.clientId, self.password , self.salt);
    return self.clientId != nil && self.password != nil && self.salt != nil &&
    ! [self.clientId isEqualToString: @""] && ! [self.password isEqualToString: @""] && ! [self.salt isEqualToString: @""];
}

- (NSString*) startSrpAuthentication {
    _srpClient = nil;
    return [[self.srpClient generateCredentialsWithSalt: [NSData dataWithHexadecimalString: self.salt] username: self.clientId password: self.password] hexadecimalString];
}

- (NSString*) processSrpChallenge: (NSString*) challenge error: (NSError**) error {
    NSData * secret = [self.srpClient calculateSecret: [NSData dataWithHexadecimalString: challenge] error: error];
    if (secret) {
        return [[self.srpClient calculateVerifier] hexadecimalString];
    }
    return nil;
}
- (BOOL) verifySrpSession: (NSString*) HAMK error: (NSError**) error {
    return [self.srpClient verifyServer: [NSData dataWithHexadecimalString: HAMK] error: error] != nil;
}

/*
- (BOOL) isAuthenticated {
    return self.srpUser.isAuthenticated;
}
*/

- (void) deleteCredentials {
    [_accountItem resetKeychainItem];
    [_saltItem resetKeychainItem];
    [[HXOUserDefaults standardUserDefaults] setBool: NO forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
    [[HXOUserDefaults standardUserDefaults] synchronize];
    NSLog(@"%@:%d", [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone], [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]);
}

- (BOOL) hasPublicKey {
    if (![HXOBackend isInvalid:self.publicKey]) {
        return YES;
    } else {
        return NO;
    }
}

- (NSString *) publicKeyId {
    return [HXOBackend keyIdString:[self publicKeyIdData]];
}

- (NSNumber*) keyLength {
    return @([CCRSA getPublicKeySize: self.publicKey]);
}

- (NSData *) publicKeyIdData {
    NSData * myKeyBits = [self publicKey];
    return [HXOBackend calcKeyId:myKeyBits];
}

- (NSData *) publicKey {
    return[[CCRSA sharedInstance] getPublicKeyBits];
}

- (SecKeyRef) getPublicKeyRef {
    return[[CCRSA sharedInstance] getPublicKeyRef];
}

- (BOOL)generateKeyPair:(NSNumber*)bits {
    CCRSA * rsa = [CCRSA sharedInstance];
    return [rsa generateKeyPairKeysWithBits:bits];
}

- (BOOL)hasKeyPair {
    CCRSA * rsa = [CCRSA sharedInstance];
    return [rsa hasKeyPair];
}

- (BOOL)saveOldKeyPair {
    CCRSA * rsa = [CCRSA sharedInstance];
    return [rsa cloneKeyPairKeys];
}

- (BOOL)deleteKeyPair {
    CCRSA * rsa = [CCRSA sharedInstance];
    return [rsa deleteKeyPairKeys];
}

- (BOOL)deleteAllKeys {
    CCRSA * rsa = [CCRSA sharedInstance];
    return [rsa deleteAllRSAKeys];
}

- (void) renewKeypair {
    [self renewKeypairWithSize: kHXODefaultKeySize];
}

- (void) renewKeypairWithSize: (NSUInteger) bits {
    [self willChangePublicKey];
    [self renewKeypairInternal: bits];
    [self didChangePublicKey];
}

- (BOOL) renewKeypairInternal: (NSUInteger) bits {
    if (self.hasKeyPair) {
        [self saveOldKeyPair];
    }
    return [self generateKeyPair: @(bits)];
}

- (void) willChangePublicKey {
    [self willChangeValueForKey: @"publicKey"];
    [self willChangeValueForKey: @"publicKeyId"];
    [self willChangeValueForKey: @"publicKeyData"];
    [self willChangeValueForKey: @"keyLength"];
}

- (void) didChangePublicKey {
    [self didChangeValueForKey: @"publicKeyData"];
    [self didChangeValueForKey: @"publicKeyId"];
    [self didChangeValueForKey: @"publicKey"];
    [self didChangeValueForKey: @"keyLength"];
}


- (void) renewKeypairWithSize: (NSUInteger) size completion: (HXOKeypairRenewalCompletion) completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{ [self willChangePublicKey]; });
        BOOL success = [self renewKeypairInternal: size];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self didChangePublicKey];
            completion(success);
        });
    });
}

- (void) renewKeypairWithCompletion: (HXOKeypairRenewalCompletion) completion {
    [self renewKeypairWithSize: kHXODefaultKeySize completion: completion];
}

- (BOOL) importKeypair: (NSString*) pemText {
    if (self.hasKeyPair) {
        [self saveOldKeyPair];
    }
    //NSLog(@"pemText:%@\n",pemText);
    [self willChangePublicKey];
    BOOL success = [[CCRSA sharedInstance] importKeypairFromPEM: pemText];
    [self didChangePublicKey];
    return success;
}

@end
