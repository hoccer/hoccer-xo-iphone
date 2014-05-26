//
//  HXOClientProtocol.h
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol HXOClientProtocol <NSObject>

@property (nonatomic, strong) NSData   * avatar;
@property (nonatomic, strong) UIImage  * avatarImage;
@property (nonatomic, strong) NSString * avatarURL;
@property (nonatomic, strong) NSString * avatarUploadURL;
@property (nonatomic, strong) NSString * clientId;
@property (nonatomic, strong) NSString * nickName;
@property (nonatomic, strong) NSData   * publicKey;       // public key of this contact
@property (nonatomic, strong) NSString * publicKeyId;     // id of public key
@property (nonatomic, strong) NSString * publicKeyString; // b64-string
@property (readonly)          NSNumber * keyLength;       // length of public key in Bits
@property (nonatomic, strong) NSString * status;
//@property (nonatomic, strong) NSString*     connectionStatus;

@end
