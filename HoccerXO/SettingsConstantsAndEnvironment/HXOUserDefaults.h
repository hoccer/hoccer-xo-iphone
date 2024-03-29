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
FOUNDATION_EXPORT NSString * const kHXOlatestBuildRun;
FOUNDATION_EXPORT NSString * const kHXOrunningNewBuild;

FOUNDATION_EXPORT NSString * const kHXOlastActiveDate;
FOUNDATION_EXPORT NSString * const kHXOlastDeactivationDate;
FOUNDATION_EXPORT NSString * const kHXOlastLogOffDate;

FOUNDATION_EXPORT NSString * const kHXOAPNDeviceToken;

FOUNDATION_EXPORT NSString * const kHXOAvatar;
FOUNDATION_EXPORT NSString * const kHXONickName;
FOUNDATION_EXPORT NSString * const kHXOAvatarURL;
FOUNDATION_EXPORT NSString * const kHXOAvatarUploadURL;
FOUNDATION_EXPORT NSString * const kHXOUserStatus;

FOUNDATION_EXPORT NSString * const kHXOAutoDownloadLimitWLAN;
FOUNDATION_EXPORT NSString * const kHXOAutoUploadLimitWLAN;
FOUNDATION_EXPORT NSString * const kHXOAutoDownloadLimitCellular;
FOUNDATION_EXPORT NSString * const kHXOAutoUploadLimitCellular;
FOUNDATION_EXPORT NSString * const kHXOMaxAttachmentUploadRetries;
FOUNDATION_EXPORT NSString * const kHXOMaxAttachmentDownloadRetries;

FOUNDATION_EXPORT NSString * const kHXOSaveDatabasePolicy;
FOUNDATION_EXPORT NSString * const kHXOSaveDatabasePolicyDelayed;

FOUNDATION_EXPORT NSString * const kHXOPreviewImageWidth;
//FOUNDATION_EXPORT NSString * const kHXOMessageFontSize;
FOUNDATION_EXPORT NSString * const kHXOManualKeyManagement;
FOUNDATION_EXPORT NSString * const kHXOSignMessages;

FOUNDATION_EXPORT NSString * const kHXOHttpServerPassword;


FOUNDATION_EXPORT NSString * const kHXODefaultScreenShooting;

FOUNDATION_EXPORT NSString * const kHXOReportCrashes;
FOUNDATION_EXPORT NSString * const kHXOSupportTag;

FOUNDATION_EXPORT NSString * const kHXODebugServerURL;
FOUNDATION_EXPORT NSString * const kHXOForceFilecacheURL;
FOUNDATION_EXPORT NSString * const kHXOConfirmMessagesSeen;

FOUNDATION_EXPORT NSString * const kHXODebugAllowUntrustedCertificates;

FOUNDATION_EXPORT NSString * const kHXOMPMediaAccess;
FOUNDATION_EXPORT NSString * const kHXOAccessControlPasscodeMode;

FOUNDATION_EXPORT NSString * const kHXOAccessControlTimeout;
FOUNDATION_EXPORT NSString * const kHXOAccessControlPassscode;
FOUNDATION_EXPORT NSString * const kHXOAccessControlTouchIdEnabled;

FOUNDATION_EXPORT NSString * const kHXOAnonymousNotifications;
FOUNDATION_EXPORT NSString * const kHXOAccessControlPhotoEnabled;

FOUNDATION_EXPORT NSString * const kHXOWorldwideNotifications;
FOUNDATION_EXPORT NSString * const kHXOWorldwideTimeToLive;
FOUNDATION_EXPORT NSString * const kHXOWorldwideGroupTag;
FOUNDATION_EXPORT NSString * const kHXOWorldwideDialogShown;
FOUNDATION_EXPORT NSString * const kHXOWorldwideAutoDownload;
FOUNDATION_EXPORT NSString * const kHXOWorldwideHidden;

FOUNDATION_EXPORT NSString * const kHXONearbyDialogShown;

FOUNDATION_EXPORT NSString * const kHXOShowMugshotDialog;


@interface HXOUserDefaults : NSObject

+ (id) standardUserDefaults;

@end
