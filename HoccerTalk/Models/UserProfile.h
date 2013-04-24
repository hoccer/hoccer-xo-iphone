//
//  UserProfile.h
//  HoccerTalk
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

@property (nonatomic,strong) NSString   * nickName;
@property (nonatomic,strong) NSString   * status;
@property (nonatomic,strong) NSString   * phoneNumber;
@property (nonatomic,strong) NSString   * mailAddress;
@property (nonatomic,strong) NSString   * twitterName;
@property (nonatomic,strong) NSString   * facebookName;
@property (nonatomic,strong) NSString   * googlePlusName;
@property (nonatomic,strong) NSString   * githubName;

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

- (NSString*) startSrpAuthentication;
- (NSString*) processSrpChallenge: (NSString*) challenge;
- (BOOL)      verifySrpSession: (NSString*) HAMK;

+ (UserProfile*) sharedProfile;

@end
