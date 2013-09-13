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
// @dynamic myGroupMembership;

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

/*
- (GroupMembership*) ownMemberShip {
    return self.myGroupMembership;

    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact == nil || [obj.contact isEqual:self];
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
 */

- (NSSet*) otherJoinedMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return ![self isEqual:obj.contact] && [obj.state isEqualToString:@"joined"];
    }];
    return theMemberSet;
}

- (NSSet*) otherInvitedMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return ![self isEqual:obj.contact] && [obj.state isEqualToString:@"invited"];
    }];
    return theMemberSet;
}

- (NSDate *) latestMemberChangeDate {
    NSSet * myMembers = self.members;
    NSDate * latestDate = [NSDate dateWithTimeIntervalSince1970:0];
    for (GroupMembership * m in myMembers) {
        latestDate = [m.lastChanged laterDate:latestDate];
    }
    return latestDate;
}

- (NSData*) groupKey {
    [self willAccessValueForKey:@"groupKey"];
    NSData * myValue = [self primitiveValueForKey:@"groupKey"];
    [self didAccessValueForKey:@"groupKey"];
    
    NSData * myMembershipValue = [self.myGroupMembership decryptedGroupKey];
    if (![HXOBackend isInvalid:myMembershipValue]) {
        // we have a good value in membership, prefer it
        if (!self.iAmAdmin) { // when I am admin, don't try to use the one from server
            if (![myMembershipValue isEqualToData:myValue]) {
                NSLog(@"Group key for group name %@ id %@ has changed", self.nickName, self.clientId);
            }
            // otherwise always use the server provided one
            myValue = myMembershipValue;
            self.groupKey = myValue;
        }
    }
    return myValue;
}

- (BOOL) iAmAdmin {
    return [self.myGroupMembership.role isEqualToString:@"admin"];
}

- (BOOL) iJoined {
    return [self.myGroupMembership.state isEqualToString:@"joined"];
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
