//
//  UserProfile.h
//  HoccerXO
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// NOT a core data model, but a model nonetheless. 

@interface UserProfile : NSObject

@property (nonatomic,strong) UIImage    * avatarImage;
@property (nonatomic,readonly) NSData   * avatar;
@property (nonatomic,strong) NSString   * avatarURL;
@property (nonatomic,strong) NSString   * avatarUploadURL;

@property (nonatomic,strong) NSString   * nickName;
@property (nonatomic,strong) NSString   * status;

@property (nonatomic,readonly) NSString * groupMembershipList;


// credentials - stored in keychain
@property (nonatomic,readonly) NSString * clientId;
@property (nonatomic,readonly) NSString * password;
@property (nonatomic,readonly) NSString * salt;

@property (nonatomic,readonly) BOOL       isAuthenticated;
@property (nonatomic,readonly) BOOL       isRegistered;

- (void) loadProfile;
- (void) saveProfile;

- (NSString*) registerClientAndComputeVerifier: (NSString*) clientId;
- (void) deleteCredentials;

- (BOOL) foundCredentialsFile;
- (BOOL) deleteCredentialsFile;

- (NSDictionary*) loadCredentialsWithPassphrase:(NSString*)passphrase;
- (int) importCredentialsWithPassphrase:(NSString*)passphrase;
- (void) exportCredentialsWithPassphrase:(NSString*)passphrase;

- (NSString*) startSrpAuthentication;
- (NSString*) processSrpChallenge: (NSString*) challenge error: (NSError**) error;
- (BOOL)      verifySrpSession: (NSString*) HAMK error: (NSError**) error;

+ (UserProfile*) sharedProfile;
+(NSURL*)getKeyFileURLWithKeyTypeName:(NSString*)keyTypeName forUser:(NSString*)userName withKeyId:(NSString*)keyId;

@end
