//
//  UserProfile.h
//  HoccerXO
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HXOClientProtocol.h"


// NOT a core data model, but a model nonetheless. 

typedef void(^HXOKeypairRenewalCompletion)(BOOL success);

FOUNDATION_EXPORT const NSUInteger kHXODefaultKeySize;

@interface UserProfile : NSObject <HXOClientProtocol>

@property (nonatomic,strong)   UIImage  * avatarImage;
@property (nonatomic,strong)   NSData   * avatar;
@property (nonatomic,strong)   NSString * avatarURL;
@property (nonatomic,strong)   NSString * avatarUploadURL;

@property (nonatomic,strong)   NSString * nickName;
@property (nonatomic,strong)   NSString * status;
@property (nonatomic,strong)   NSString * connectionStatus;

@property (nonatomic, strong) NSData   * publicKey;       // public key of this contact
@property (nonatomic, strong) NSString * publicKeyId;     // id of public key
@property (nonatomic, strong) NSData   * publicKeyIdData; // public key of this contact
@property (nonatomic, strong) NSString * publicKeyString; // b64-string
@property (readonly)          NSNumber * keyLength;       // length of public key in bits

@property BOOL                            deletedObject;


@property (nonatomic,readonly) NSString * groupMembershipList;

// credentials - stored in keychain
@property (nonatomic,strong)   NSString * clientId;
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

- (BOOL)transferCredentials;
- (int)importCredentialsJson:(NSData*)jsonData;


- (NSString*) startSrpAuthentication;
- (NSString*) processSrpChallenge: (NSString*) challenge error: (NSError**) error;
- (BOOL)      verifySrpSession: (NSString*) HAMK error: (NSError**) error;

+ (UserProfile*) sharedProfile;
+(NSURL*)getKeyFileURLWithKeyTypeName:(NSString*)keyTypeName forUser:(NSString*)userName withKeyId:(NSString*)keyId;

- (void) renewKeypair;
- (void) renewKeypairWithSize: (NSUInteger) size;
- (void) renewKeypairWithSize: (NSUInteger) size completion: (HXOKeypairRenewalCompletion) completion;
- (void) renewKeypairWithCompletion: (HXOKeypairRenewalCompletion) completion;

- (BOOL) importKeypair: (NSString*) pemText;

- (BOOL)generateKeyPair:(NSNumber*)bits;
- (BOOL)hasKeyPair;
- (BOOL)hasPublicKey;
- (BOOL)saveOldKeyPair;
- (BOOL)deleteKeyPair;
- (BOOL)deleteAllKeys;
- (SecKeyRef) getPublicKeyRef;



@end
