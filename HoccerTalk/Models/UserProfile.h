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

@property (nonatomic,strong) NSString * nickName;

// credentials - stored in keychain
@property (nonatomic,readonly) NSString * clientId;
@property (nonatomic,readonly) NSString * password;
@property (nonatomic,readonly) NSString * salt;

- (NSString*) registerClientAndComputeVerifier: (NSString*) clientId;
- (void) deleteCredentials;

+ (UserProfile*) sharedProfile;

@end
