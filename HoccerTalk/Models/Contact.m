//
//  Contact.m
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Contact.h"

const float kTimeSectionInterval = 2 * 60;

@implementation Contact

@dynamic avatar;
@dynamic clientId;
@dynamic latestMessageTime;
@dynamic nickName;
@dynamic state;
@dynamic relationship;

@dynamic currentTimeSection;
@dynamic unreadMessages;
@dynamic latestMessage;

@dynamic messages;

@synthesize avatarImage = _avatarImage;

- (UIImage*) avatarImage {
    if (_avatarImage != nil) {
        return _avatarImage;
    }

    _avatarImage = self.avatar != nil ? [UIImage imageWithData: self.avatar] : [UIImage imageNamed: @"avatar_default_contact"];

    return _avatarImage;
}

- (NSString*) sectionTitleForMessageTime: (NSDate*) date {
    if (self.latestMessageTime == nil) {
        self.latestMessageTime = [NSDate date];
    }
    if ([date timeIntervalSinceDate: self.latestMessageTime] > kTimeSectionInterval || self.currentTimeSection == nil) {
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        self.currentTimeSection = [formatter stringFromDate: date];
    }
    return self.currentTimeSection;
}
@end
