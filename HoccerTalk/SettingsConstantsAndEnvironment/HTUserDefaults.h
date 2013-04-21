//
//  UserDefaultsKeys.h
//  HoccerTalk
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const kHTEnvironment;
FOUNDATION_EXPORT NSString * const kHTFirstRunDone;
FOUNDATION_EXPORT NSString * const kHTAPNDeviceToken;
FOUNDATION_EXPORT NSString * const kHTClientId;
FOUNDATION_EXPORT NSString * const kHTPassword;
FOUNDATION_EXPORT NSString * const kHTSrpSalt;
FOUNDATION_EXPORT NSString * const kHTAvatar;
FOUNDATION_EXPORT NSString * const kHTNickName;
FOUNDATION_EXPORT NSString * const kHTAvatarURL;
FOUNDATION_EXPORT NSString * const kHTUserStatus;
FOUNDATION_EXPORT NSString * const kHTAutoDownloadLimit;
FOUNDATION_EXPORT NSString * const kHTAutoUploadLimit;
FOUNDATION_EXPORT NSString * const kHTMaxAttachmentUploadRetries;
FOUNDATION_EXPORT NSString * const kHTMaxAttachmentDownloadRetries;

FOUNDATION_EXPORT NSString * const kHTSaveDatabasePolicy;
FOUNDATION_EXPORT NSString * const kHTSaveDatabasePolicyPerMessage;

FOUNDATION_EXPORT NSString * const kHTDefaultScreenShooting;



@interface HTUserDefaults : NSObject

+ (id) standardUserDefaults;

@end
