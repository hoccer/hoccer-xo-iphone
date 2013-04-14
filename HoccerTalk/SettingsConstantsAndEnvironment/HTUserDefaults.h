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
FOUNDATION_EXPORT NSString * const kHTAvatarImage;
FOUNDATION_EXPORT NSString * const kHTNickName;
FOUNDATION_EXPORT NSString * const kHTAvatarURL;
FOUNDATION_EXPORT NSString * const kHTUserStatus;
FOUNDATION_EXPORT NSString * const kHTDefaultScreenShooting;



@interface HTUserDefaults : NSObject

+ (id) standardUserDefaults;

@end