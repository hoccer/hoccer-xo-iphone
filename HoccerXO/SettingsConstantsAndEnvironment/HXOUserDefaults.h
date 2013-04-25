//
//  UserDefaultsKeys.h
//  HoccerXO
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const kHXOEnvironment;
FOUNDATION_EXPORT NSString * const kHXOFirstRunDone;
FOUNDATION_EXPORT NSString * const kHXOAPNDeviceToken;

FOUNDATION_EXPORT NSString * const kHXOAvatar;
FOUNDATION_EXPORT NSString * const kHXONickName;
FOUNDATION_EXPORT NSString * const kHXOAvatarURL;
FOUNDATION_EXPORT NSString * const kHXOUserStatus;
FOUNDATION_EXPORT NSString * const kHXOPhoneNumber;
FOUNDATION_EXPORT NSString * const kHXOMailAddress;
FOUNDATION_EXPORT NSString * const kHXOTwitterName;
FOUNDATION_EXPORT NSString * const kHXOFacebookName;
FOUNDATION_EXPORT NSString * const kHXOGooglePlusName;
FOUNDATION_EXPORT NSString * const kHXOGithubName;

FOUNDATION_EXPORT NSString * const kHXOAutoDownloadLimit;
FOUNDATION_EXPORT NSString * const kHXOAutoUploadLimit;
FOUNDATION_EXPORT NSString * const kHXOMaxAttachmentUploadRetries;
FOUNDATION_EXPORT NSString * const kHXOMaxAttachmentDownloadRetries;

FOUNDATION_EXPORT NSString * const kHXOSaveDatabasePolicy;
FOUNDATION_EXPORT NSString * const kHXOSaveDatabasePolicyPerMessage;

FOUNDATION_EXPORT NSString * const kHXOPreviewImageWidth;

FOUNDATION_EXPORT NSString * const kHXODefaultScreenShooting;


@interface HXOUserDefaults : NSObject

+ (id) standardUserDefaults;

@end
