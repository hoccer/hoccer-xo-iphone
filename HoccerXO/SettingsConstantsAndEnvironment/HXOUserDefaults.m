//
//  UserDefaultsKeys.m
//  HoccerXO
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOUserDefaults.h"

NSString * const kHXOEnvironment           = @"environment";
NSString * const kHXOFirstRunDone          = @"firstRunDone";
NSString * const kHXOlatestBuildRun        = @"latestBuildRun";
NSString * const kHXOAPNDeviceToken        = @"apnDeviceToken";

NSString * const kHXOAvatar                = @"avatar";
NSString * const kHXOAvatarURL             = @"avatarURL";
NSString * const kHXOAvatarUploadURL       = @"avatarUploadURL";
NSString * const kHXONickName              = @"nickName";
NSString * const kHXOUserStatus            = @"userStatus";
NSString * const kHXOPhoneNumber           = @"phoneNumber";
NSString * const kHXOMailAddress           = @"mailAddress";
NSString * const kHXOTwitterName           = @"twitterName";
NSString * const kHXOFacebookName          = @"facebookName";
NSString * const kHXOGooglePlusName        = @"googlePlusName";
NSString * const kHXOGithubName            = @"githubName";

NSString * const kHXODefaultScreenShooting = @"defaultScreenShooting";
NSString * const kHXOAutoDownloadLimit     = @"autoDownloadLimit";
NSString * const kHXOAutoUploadLimit       = @"autoUploadLimit";

NSString * const kHXOMaxAttachmentUploadRetries   = @"maxAttachmentUploadRetries";
NSString * const kHXOMaxAttachmentDownloadRetries = @"maxAttachmentDownloadRetries";

NSString * const kHXOSaveDatabasePolicy    = @"saveDatabasePolicy";
NSString * const kHXOSaveDatabasePolicyPerMessage  = @"perMessage";

NSString * const kHXOPreviewImageWidth      = @"previewImageWidth";

NSString * const kHXODefaultsDefaultsFile = @"HXOUserDefaultsDefaults";

@implementation HXOUserDefaults

+ (void) initialize {
    NSString * path = [[NSBundle mainBundle] pathForResource: kHXODefaultsDefaultsFile ofType: @"plist"];
    NSDictionary * defaultsDefaults = [NSDictionary dictionaryWithContentsOfFile: path];
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultsDefaults];
}

+ (id) standardUserDefaults {
    return [NSUserDefaults standardUserDefaults];
}

@end
