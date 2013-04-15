//
//  UserDefaultsKeys.m
//  HoccerTalk
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HTUserDefaults.h"

NSString * const kHTEnvironment           = @"environment";
NSString * const kHTFirstRunDone          = @"firstRunDone";
NSString * const kHTAPNDeviceToken        = @"apnDeviceToken";
NSString * const kHTClientId              = @"clientId";
NSString * const kHTAvatar                = @"avatar";
NSString * const kHTAvatarURL             = @"avatarURL";
NSString * const kHTNickName              = @"nickName";
NSString * const kHTUserStatus            = @"userStatus";
NSString * const kHTDefaultScreenShooting = @"defaultScreenShooting";


NSString * const kHTDefaultsDefaultsFile = @"HTUserDefaultsDefaults";

@implementation HTUserDefaults

+ (void) initialize {
    NSString * path = [[NSBundle mainBundle] pathForResource: kHTDefaultsDefaultsFile ofType: @"plist"];
    NSDictionary * defaultsDefaults = [NSDictionary dictionaryWithContentsOfFile: path];
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultsDefaults];
}

+ (id) standardUserDefaults {
    return [NSUserDefaults standardUserDefaults];
}

@end
