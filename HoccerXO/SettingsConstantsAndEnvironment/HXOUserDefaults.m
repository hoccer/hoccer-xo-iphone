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
NSString * const kHXOrunningNewBuild       = @"runningNewBuild";
NSString * const kHXOlastActiveDate        = @"lastActiveDate";
NSString * const kHXOlastDeactivationDate  = @"lastDeactivationDate";
NSString * const kHXOAPNDeviceToken        = @"apnDeviceToken";

NSString * const kHXOAvatar                = @"avatar";
NSString * const kHXOAvatarURL             = @"avatarURL";
NSString * const kHXOAvatarUploadURL       = @"avatarUploadURL";
NSString * const kHXONickName              = @"nickName";
NSString * const kHXOUserStatus            = @"userStatus";

NSString * const kHXODefaultScreenShooting = @"defaultScreenShooting";
NSString * const kHXOAutoDownloadLimitWLAN     = @"autoDownloadLimitWLAN";
NSString * const kHXOAutoUploadLimitWLAN       = @"autoUploadLimitWLAN";
NSString * const kHXOAutoDownloadLimitCellular     = @"autoDownloadLimitCellular";
NSString * const kHXOAutoUploadLimitCellular       = @"autoUploadLimitCellular";

NSString * const kHXOMaxAttachmentUploadRetries   = @"maxAttachmentUploadRetries";
NSString * const kHXOMaxAttachmentDownloadRetries = @"maxAttachmentDownloadRetries";

NSString * const kHXOSaveDatabasePolicy    = @"saveDatabasePolicy";
NSString * const kHXOSaveDatabasePolicyDelayed  = @"delayed";

NSString * const kHXOPreviewImageWidth      = @"previewImageWidth";

NSString * const kHXOMessageFontSize       = @"messageFontSize";
NSString * const kHXOManualKeyManagement   = @"manualKeyManagement";
NSString * const kHXOSignMessages          = @"signMessages";

NSString * const kHXOHttpServerPassword    = @"httpServerPassword";

NSString * const kHXOReportCrashes         = @"reportCrashes";
NSString * const kHXOSupportTag            = @"supportTag";

NSString * const kHXOConfirmMessagesSeen   = @"confirmSeenMessages";

NSString * const kHXODebugServerURL        = @"debugServerURL";
NSString * const kHXOForceFilecacheURL     = @"forceFilecacheURL";

NSString * const kHXODebugAllowUntrustedCertificates = @"debugAllowUntrustedCertificates";

NSString * const kHXODefaultsDefaultsFile = @"HXOUserDefaultsDefaults";

NSString * const kHXOMPMediaAccess = @"mpMediaAccess";

NSString * const kHXOPasscodeMode = @"passcodeMode";


@implementation HXOUserDefaults

+ (void) initialize {
    if (self == [HXOUserDefaults class]) {
        NSString * path = [[NSBundle mainBundle] pathForResource: kHXODefaultsDefaultsFile ofType: @"plist"];
        NSDictionary * defaultsDefaults = [NSDictionary dictionaryWithContentsOfFile: path];
        [[NSUserDefaults standardUserDefaults] registerDefaults: defaultsDefaults];
    }
}

+ (id) standardUserDefaults {
    return [NSUserDefaults standardUserDefaults];
}

@end
