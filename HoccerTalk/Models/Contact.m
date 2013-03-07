//
//  Contact.m
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Contact.h"

const float kTimeSectionInterval = 2 * 60;

@implementation Contact

@dynamic avatar;
@dynamic lastMessageTime;
@dynamic nickName;
@dynamic currentTimeSection;

@dynamic messages;

@synthesize avatarImage = _avatarImage;

- (UIImage*) avatarImage {
    if (_avatarImage != nil) {
        return _avatarImage;
    }

    _avatarImage = [UIImage imageWithData: self.avatar];

    return _avatarImage;
}

- (NSString*) sectionTitleForMessageTime: (NSDate*) date {
    if (self.lastMessageTime == nil) {
        self.lastMessageTime = [NSDate date];
    }
    if ([date timeIntervalSinceDate: self.lastMessageTime] > kTimeSectionInterval || self.currentTimeSection == nil) {
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        self.currentTimeSection = [formatter stringFromDate: date];
    }
    return self.currentTimeSection;
}
@end
