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
#import "NSData+Base64.h"
#import "Crypto.h"
#import "UserProfile.h"

#define GROUPKEY_DEBUG NO

NSString * const kGroupStateNone    = @"none";
NSString * const kGroupStateExists  = @"exists";

NSString * const kGroupStateInternalIncomplete  = @"incomplete";
NSString * const kGroupStateInternalKept        = @"kept";

NSString * const kGroupTypeUser     = @"user";
NSString * const kGroupTypeNearby   = @"nearby";
NSString * const kGroupTypeWorldwide   = @"worldwide";


@implementation Group

@dynamic groupKey;
@dynamic groupTag;
@dynamic groupState;
@dynamic lastChanged;
@dynamic members;
@dynamic sharedKeyId;
@dynamic sharedKeyIdSalt;
@dynamic groupType;
@dynamic keySupplier;
@dynamic keyDate;

@dynamic sharedKeyIdString;
@dynamic sharedKeyIdSaltString;

@dynamic keyDateMillis;
@dynamic lastChangedMillis;

- (NSString*) sharedKeyIdString {
    return [self.sharedKeyId asBase64EncodedString];
}

- (void) setSharedKeyIdString:(NSString*) theB64String {
    self.sharedKeyId = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSString*) sharedKeyIdSaltString {
    return [self.sharedKeyIdSalt asBase64EncodedString];
}

- (void) setSharedKeyIdSaltString:(NSString*) theB64String {
    self.sharedKeyIdSalt = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSNumber*) keyDateMillis {
    return [HXOBackend millisFromDate:self.keyDate];
}

- (void) setKeyDateMillis:(NSNumber*) milliSecondsSince1970 {
    self.keyDate = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSSet*) otherMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return ![self isEqual:obj.contact] && !obj.isStateNone && !obj.isSuspended;
    }];
    return theMemberSet;
}

- (NSSet*) otherJoinedMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return ![self isEqual:obj.contact] && obj.isJoined;
    }];
    return theMemberSet;
}

- (NSSet*) otherInvitedMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return ![self isEqual:obj.contact] && obj.isInvited;
    }];
    return theMemberSet;
}

- (NSSet*) adminMembers {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.isJoined && obj.isAdmin;
    }];
    return theMemberSet;
}

- (NSSet*) knownAdminMembers {
    NSSet * theMemberSet = [self.adminMembers objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact.nickName != nil;
    }];
    return theMemberSet;
}

- (NSSet*) membersNotFriends {
    NSSet * theMemberSet = [self.otherMembers objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return !obj.contact.isFriend;
    }];
    return theMemberSet;
}

- (NSSet*) membersInvitable {
    NSSet * theMemberSet = [self.otherMembers objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact.isInvitable;
    }];
    return theMemberSet;
}

- (NSSet*) membersInvitedMeAsFriend {
    NSSet * theMemberSet = [self.otherMembers objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact.invitedMe;
    }];
    return theMemberSet;
}

- (NSSet*) membersInvitedAsFriend {
    NSSet * theMemberSet = [self.otherMembers objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.contact.isInvited;
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

// look for member matching memberClientId in group members
- (GroupMembership*) membershipWithClientId:(NSString*)clientId {
    if ([clientId isEqual:[UserProfile sharedProfile].clientId]) {
        return self.myGroupMembership;
    }
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        BOOL result = [clientId isEqualToString: obj.contact.clientId];
        //NSLog(@"memberWithClientId: filtering: result=%d, obj.contact.clientId=%@, clientId=%@",result,obj.contact.clientId,clientId);
        return result;
    }];
    if (theMemberSet.count == 1) {
        return theMemberSet.anyObject;
    }
    if (theMemberSet.count == 0) {
        return nil;
    }
    if (theMemberSet.count > 1) {
        NSLog(@"#ERROR: memberWithClientId: multiple members with same clientId %@", clientId);
    }
    return nil;
}


-(void)changeIdTo:(NSString*)newId removeMembers:(BOOL)removeMembers {
    NSSet * myMembers = self.members;
    for (GroupMembership * member in myMembers) {
        if (member.contact.messages.count > 0) {
            member.state = kGroupStateInternalKept;
        } else {
            member.state = kGroupStateNone;
        }
    }
    self.clientId = newId;
}

-(BOOL) hasGroupKey {
    //NSLog(@"hasGroupKey: self.groupKey = %@, self.groupKey.length = %d, self.sharedKeyId = %@, self.keySupplier = %@, self.sharedKeyIdSalt = %@", self.groupKey, self.groupKey.length, self.sharedKeyId, self.keySupplier, self.sharedKeyIdSalt);
    
    BOOL result = self.groupKey != nil && self.groupKey.length > 0 && self.sharedKeyId != nil && self.keySupplier != nil && self.sharedKeyIdSalt != nil;
   if (GROUPKEY_DEBUG)  NSLog(@"Group;hasGroupKey: %@", result ? @"YES" : @"NO");
    return result;
}

-(void) generateNewGroupKey {
    if (GROUPKEY_DEBUG) {NSLog(@"Group:generateNewGroupKey");}
    self.groupKey = [Crypto random256BitKey];
    self.sharedKeyIdSalt = [Crypto random256BitSalt];
    self.keySupplier = [UserProfile sharedProfile].clientId;
    self.sharedKeyId = [Crypto calcSymmetricKeyId:self.groupKey withSalt:self.sharedKeyIdSalt];
    self.keyDateMillis = @0; // 0 indicates a local date not yet transmitted via the server which will give it a proper time stamp
    if (![self hasGroupKey]) {
        NSLog(@"ERROR: Group:generateNewGroupKey: hasGroupKey failed");
    }
    //if (GROUPKEY_DEBUG) [self checkGroupKey];
}


-(BOOL) copyKeyFromMember:(GroupMembership*)member {
    if (GROUPKEY_DEBUG) NSLog(@"Group:copyKeyFromMember: %@",member.contact.clientId);
    NSData * myGroupKey = member.decryptedGroupKey;
    if (myGroupKey != nil) {
        NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:myGroupKey withSalt:member.sharedKeyIdSalt];
        if (![myGroupKeyId isEqualToData:member.sharedKeyId]) {
            NSLog(@"Group:copyKeyFromMember: groupKeyId mismatch, shared key id from decrypted group key does not match computed key id, group nick %@, member nick %@, computed myGroupKeyId=%@, stored member.sharedKeyId=%@", self.nickName, member.contact.nickName,myGroupKeyId, member.sharedKeyId);
            // trash bad key values
            member.sharedKeyIdSalt = nil;
            member.sharedKeyId = nil;
            member.cipheredGroupKey = nil;
            member.keySupplier = nil;
            return NO;
        }
        self.groupKey = myGroupKey;
        self.sharedKeyIdSalt = member.sharedKeyIdSalt;
        self.sharedKeyId = member.sharedKeyId;
        self.keySupplier = member.keySupplier;
        self.keyDate = member.sharedKeyDate;
        if (![self hasGroupKey]) {
            NSLog(@"ERROR: Group:copyKeyFromMember: hasGroupKey failed");
        }
        // if (GROUPKEY_DEBUG) [self checkGroupKey];
        return YES;
    } else {
        NSLog(@"ERROR: Group:copyKeyFromMember: member.decryptedGroupKey failed");
    }
    return NO;
}

/*
-(BOOL) hasValidGroupKey {
    if (self.groupKey == nil || self.sharedKeyIdSalt == nil) {
        return NO;
    }
    NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:self.groupKey withSalt:self.sharedKeyIdSalt];
    if (myGroupKeyId == nil) {
        if (GROUPKEY_DEBUG) NSLog(@"Group hasValidGroupKey: nil id, self.groupKey = %@, self.sharedKeyIdSalt = %@", self.groupKey, self.sharedKeyIdSalt);
        //NSLog(@"%@",[NSThread callStackSymbols]);
        return NO;
    }
    if (![myGroupKeyId isEqualToData:self.sharedKeyId]) {
        if (GROUPKEY_DEBUG) NSLog(@"Group hasValidGroupKey mismatch: stored id = %@, computed id = %@", self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
        //NSLog(@"%@",[NSThread callStackSymbols]);
        NSLog(@"Group hasValidGroupKey: trashing bad group key for group %@ nick %@", self.clientId, self.nickName);
        // trash invalid group key
        self.groupKey = nil;
        self.sharedKeyIdSalt = nil;
        self.sharedKeyId = nil;
        self.keySupplier = nil;
        self.keyDate = nil;
        return NO;
    }
    if (GROUPKEY_DEBUG) NSLog(@"Group:hasValidGroupKey: YES");
    return YES;
}
*/
- (BOOL) hasAdmin {
    return self.adminMembers.count > 0;
}

- (BOOL) hasKnownAdmins {
    return self.knownAdminMembers.count > 0;
}

- (BOOL) iAmAdmin {
    return [kGroupMembershipRoleAdmin isEqualToString: self.myGroupMembership.role];
}

- (BOOL) iJoined {
    return [kGroupMembershipStateJoined isEqualToString: self.myGroupMembership.state];
}

- (BOOL)isKeptGroup {
    return [kGroupStateInternalKept isEqualToString:self.groupState];
}

- (BOOL)isRemovedGroup {
    return [kRelationStateNone isEqualToString:self.groupState];
}

- (BOOL)isExistingGroup {
    return [kGroupStateExists isEqualToString:self.groupState];
}

- (BOOL)isIncompleteGroup {
    return [kGroupStateInternalIncomplete isEqualToString:self.groupState];
}

- (BOOL)isNearbyGroup{
    return [kGroupTypeNearby isEqualToString: self.groupType];
}

- (BOOL)isWorldwideGroup{
    return [kGroupTypeWorldwide isEqualToString: self.groupType];
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
              @"groupType"       : @"groupType",
              @"keySupplier"     : @"keySupplier",
              @"state"           : @"groupState",
              //@"groupAvatarUrl"  : @"avatarURL", // only for outgoing
              @"lastChanged"     : @"lastChangedMillis",
              @"sharedKeyId"     : @"sharedKeyIdString",
              @"sharedKeyIdSalt" : @"sharedKeyIdSaltString",
              @"keyDate"         : @"keyDateMillis"
              };
}




@end
