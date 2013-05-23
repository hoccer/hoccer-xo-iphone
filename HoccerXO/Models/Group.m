//
//  Group.m
//  HoccerXO
//
//  Created by David Siegel on 15.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Group.h"
#import "GroupMembership.h"
#import "HXOBackend.h"


@implementation Group

@dynamic groupKey;
@dynamic myRole;
@dynamic myState;
@dynamic groupTag;
@dynamic lastChanged;
@dynamic members;

@dynamic lastChangedMillis;
@dynamic ownMemberShip;

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (GroupMembership*) ownMemberShip {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact == nil;
    }];
    if ([theMemberSet count] == 1) {
        return theMemberSet.anyObject;
    }
    return nil;
}

//public class TalkGroup {
//    public String groupTag;
//    public String groupId;
//    public String groupName;
//    public String groupAvatarUrl;
//    public Date lastChanged;
//}

- (NSDictionary*) rpcKeys {
    return @{ @"groupId"         : @"clientId",
              @"groupTag"        : @"groupTag",
              @"groupName"       : @"nickName",
              @"groupAvatarUrl"  : @"avatarURL",
              @"lastChanged"     : @"lastChangedMillis"
              };
}




@end
