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
@dynamic groupTag;
@dynamic groupState;
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
        if ([theMemberSet.anyObject isEqual:self.myGroupMembership]) {
            return theMemberSet.anyObject;
        } else {
            NSLog(@"ERROR: link to own membership does not match object in memberships, database inconsistency, group=%@", self);
        }
    } else if (theMemberSet.count > 1) {
        NSLog(@"ERROR: expected one own membership but found %d", theMemberSet.count);
    }
    return nil;
}

- (NSSet*) otherJoinedMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact != nil && [obj.state isEqualToString:@"joined"];
    }];
    return theMemberSet;
}

- (NSSet*) otherInvitedMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact != nil && [obj.state isEqualToString:@"invited"];
    }];
    return theMemberSet;
}

- (NSData*) groupKey {
    [self willAccessValueForKey:@"groupKey"];
    NSData * myValue = [self primitiveValueForKey:@"groupKey"];
    [self didAccessValueForKey:@"groupKey"];
    if (myValue == nil) {
        myValue = [self.ownMemberShip decryptedGroupKey];
        self.groupKey = myValue;
    }
    return myValue;
}

- (BOOL) iAmAdmin {
    return [self.ownMemberShip.role isEqualToString:@"admin"];
}

- (BOOL) iJoined {
    return [self.ownMemberShip.state isEqualToString:@"joined"];
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
              @"state"           : @"groupState",
              //@"groupAvatarUrl"  : @"avatarURL", // only for outgoing
              @"lastChanged"     : @"lastChangedMillis"
              };
}




@end
