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

#define GROUPKEY_DEBUG YES

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
// @dynamic myGroupMembership;


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

- (NSSet*) activeMembersWithClientIds:(NSArray*)clientIds {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        BOOL stateOK = ([obj.state isEqualToString:@"invited"] || [obj.state isEqualToString:@"invited"]);
        BOOL pubKeyOK = obj.contactPubKeyId != nil && obj.contactHasPubKey;
        BOOL contains = [clientIds containsObject:obj.contactClientId];
        NSLog(@"activeMembersWithClientIds:filtering: %@", obj.contactClientId);
        NSLog(@"activeMembersWithClientIds:stateOK: %@", stateOK ? @"YES" : @"NO");
        NSLog(@"activeMembersWithClientIds:pubKeyOK: %@", pubKeyOK ? @"YES" : @"NO");
        NSLog(@"activeMembersWithClientIds:contains: %@", contains ? @"YES" : @"NO");
        return stateOK && pubKeyOK && contains;
    }];
    NSLog(@"activeMembersWithClientIds:passed %d members", theMemberSet.count);
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

-(BOOL) hasGroupKey {
    //NSLog(@"hasGroupKey: self.groupKey = %@, self.groupKey.length = %d, self.sharedKeyId = %@, self.keySupplier = %@, self.sharedKeyIdSalt = %@", self.groupKey, self.groupKey.length, self.sharedKeyId, self.keySupplier, self.sharedKeyIdSalt);
    
    BOOL result = self.groupKey != nil && self.groupKey.length > 0 && self.sharedKeyId != nil && self.keySupplier != nil && self.sharedKeyIdSalt != nil;
    NSLog(@"Group;hasGroupKey: %@", result ? @"YES" : @"NO");
    return result;
}

-(void) generateNewGroupKey {
    if (self.iAmAdmin) {
        if (GROUPKEY_DEBUG) {NSLog(@"Group:generateNewGroupKey");}
        self.groupKey = [Crypto random256BitKey];
        self.sharedKeyIdSalt = [Crypto random256BitSalt];
        self.keySupplier = [UserProfile sharedProfile].clientId;
        self.sharedKeyId = [Crypto calcSymmetricKeyId:self.groupKey withSalt:self.sharedKeyIdSalt];
        self.keyDateMillis = @0; // 0 indicates a local date not yet transmitted via the server which will give it a proper time stamp
        if (![self hasGroupKey]) {
            NSLog(@"Group:generateNewGroupKey: hasGroupKey failed");
        }
        [self checkGroupKey];
    } else {
        NSLog(@"Group:generateNewGroupKey: can't generate (not admin), group nick %@, id %@", self.nickName, self.clientId);
    }
}

-(BOOL) copyKeyFromMember:(GroupMembership*)member {
    NSLog(@"Group:copyKeyFromMember: %@",member.contact.clientId);
    NSData * myGroupKey = member.decryptedGroupKey;
    if (myGroupKey != nil) {
        NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:myGroupKey withSalt:member.sharedKeyIdSalt];
        if (![myGroupKeyId isEqualToData:member.sharedKeyId]) {
            NSLog(@"Group:copyKeyFromMember: groupKeyId mismatch, shared key id from decrypted group key does not match computed key id, group nick %@, member nick %@, computed myGroupKeyId=%@, stored member.sharedKeyId=%@", self.nickName, member.contact.nickName,myGroupKeyId, member.sharedKeyId);
            return NO;
        }
        self.groupKey = myGroupKey;
        self.sharedKeyIdSalt = member.sharedKeyIdSalt;
        self.sharedKeyId = member.sharedKeyId;
        self.keySupplier = member.keySupplier;
        self.keyDate = member.sharedKeyDate;
        if (![self hasGroupKey]) {
            NSLog(@"Group:copyKeyFromMember: hasGroupKey failed");
        }
        [self checkGroupKey];
        return YES;
    } else {
        NSLog(@"Group:copyKeyFromMember:  member.decryptedGroupKey failed");
    }
    return NO;
}

-(BOOL) hasValidGroupKey {
    NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:self.groupKey withSalt:self.sharedKeyIdSalt];
    if (myGroupKeyId == nil) {
        NSLog(@"Group hasValidGroupKey: nil id, self.groupKey = %@, self.sharedKeyIdSalt = %@", self.groupKey, self.sharedKeyIdSalt);
        //NSLog(@"%@",[NSThread callStackSymbols]);
        return NO;
    }
    if (![myGroupKeyId isEqualToData:self.sharedKeyId]) {
        NSLog(@"Group hasValidGroupKey mismatch: stored id = %@, computed id = %@", self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
        //NSLog(@"%@",[NSThread callStackSymbols]);
        return NO;
    }
    NSLog(@"Group:hasValidGroupKey: YES");
    return YES;
}

- (BOOL)syncKeyWithMembership {
    NSLog(@"Group:syncKeyWithMember:");
    GroupMembership * ownMember = self.myGroupMembership;
    if (ownMember == nil) {
        NSLog(@"Group:syncKeyWithMember: no own member");
        return NO;
    }
    if (ownMember.hasLatestGroupKey || (ownMember.hasValidGroupKey && !self.hasValidGroupKey)) {
        NSLog(@"Group:syncKeyWithMember: copyKeyFromMember");
        [self copyKeyFromMember:ownMember];
        return NO;
    }
    if (self.hasValidGroupKey && !ownMember.hasLatestGroupKey) {
        NSLog(@"Group:syncKeyWithMember: updateKeyFromGroup");
        [ownMember updateKeyFromGroup];
        return YES;
    }
    NSLog(@"Group:syncKeyWithMember: NO");
    return NO;
}


-(BOOL) checkGroupKey {
    NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:self.groupKey withSalt:self.sharedKeyIdSalt];
    if (myGroupKeyId == nil) {
        NSLog(@"Group checkGroupKey: nil id, self.groupKey = %@, self.sharedKeyIdSalt = %@", self.groupKey, self.sharedKeyIdSalt);
        NSLog(@"%@",[NSThread callStackSymbols]);
        return NO;
    }
    if (![myGroupKeyId isEqualToData:self.sharedKeyId]) {
        //@throw [NSException exceptionWithName: @"checkGroupKeyFailure" reason: @"stored id does not match computed id" userInfo: nil];
        NSLog(@"Group checkGroupKey mismatch, deleting group key: stored id = %@, computed id = %@", self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
        NSLog(@"%@",[NSThread callStackSymbols]);
        self.groupKey = nil;
        if (self.myGroupMembership != nil) {
            if (self.myGroupMembership.sharedKeyId != nil && [self.myGroupMembership.sharedKeyId isEqualToData:self.sharedKeyId]) {
                if ([self copyKeyFromMember:self.myGroupMembership]) {
                    myGroupKeyId = [Crypto calcSymmetricKeyId:self.groupKey withSalt:self.sharedKeyIdSalt];
                    NSLog(@"Group checkGroupKey: copied key from member, stored id = %@, computed id = %@", self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
                    return YES;
                }
            }
            NSLog(@"Group checkGroupKey: deleting all myGroupMembership key material");
            self.myGroupMembership.cipheredGroupKey = nil;
            self.myGroupMembership.memberKeyId = nil;
            self.myGroupMembership.sharedKeyIdSalt = nil;
            self.myGroupMembership.sharedKeyId = nil;
        }
        return NO;
    }
    return YES;
}


/*
 lets try get along without this and set the group key instead only when the membership update arrives or via generateNewGroupKey

 - (NSData*) groupKey {
    [self willAccessValueForKey:@"groupKey"];
    NSData * myValue = [self primitiveValueForKey:@"groupKey"];
    [self didAccessValueForKey:@"groupKey"];
    
    if ([self.myGroupMembership hasCipheredGroupKey]) {
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
    }
    return myValue;
}
 */

- (BOOL) iAmAdmin {
    return [self.myGroupMembership.role isEqualToString:@"admin"];
}

- (BOOL) iJoined {
    return [self.myGroupMembership.state isEqualToString:@"joined"];
}


- (BOOL) hasKeyOnServer {
    BOOL result = self.keySupplier != nil && self.sharedKeyId != nil && self.sharedKeyIdSalt != nil && self.keyDate != nil;
    NSLog(@"Group;hasKeyOnServer: %@", result ? @"YES" : @"NO");
    return result;
}

- (BOOL) hasKeyMaster {
    NSDate * estimatedServerTime = [HXOBackend.instance estimatedServerTime];
    NSTimeInterval passed = [estimatedServerTime timeIntervalSinceDate:self.keyDate];
    NSLog(@"Group;hasKeyMaster: estimatedServerTime %@, keyDate %@, passed = %f", estimatedServerTime, self.keyDate, passed);
    BOOL result = [self hasKeyOnServer] && [[HXOBackend.instance estimatedServerTime] timeIntervalSinceDate:self.keyDate] < 60.0;
    NSLog(@"Group;hasKeyMaster: %@", result ? @"YES" : @"NO");
    return result;
}

- (BOOL) iAmKeyMaster {
    BOOL result = self.iAmAdmin && self.hasKeyMaster && [self.keySupplier isEqualToString:UserProfile.sharedProfile.clientId];
    NSLog(@"Group;iAmKeyMaster: %@", result ? @"YES" : @"NO");
    return result;
}

- (BOOL) iCanSetKeys {
    BOOL result = !self.hasKeyMaster || self.iAmKeyMaster;
    NSLog(@"Group;iCanSetKeys: %@", result ? @"YES" : @"NO");
    return result;
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
