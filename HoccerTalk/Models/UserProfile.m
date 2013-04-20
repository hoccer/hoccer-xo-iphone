//
//  UserProfile.m
//  HoccerTalk
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserProfile.h"

static UserProfile * profileInstance;

@implementation UserProfile

- (id) init {
    self = [super init];
    if (self != nil) {

    }
    return self;
}

+ (void) initialize {
    profileInstance = [[UserProfile alloc] init];
}

+ (UserProfile*) myProfile {
    return profileInstance;
}

@end
