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

@synthesize updatesRefused;
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
        BOOL stateOK = ([obj.state isEqualToString:@"invited"] || [obj.state isEqualToString:@"joined"]);
        BOOL pubKeyOK = obj.contactPubKeyId != nil && obj.contactHasPubKey;
        BOOL contains = [clientIds containsObject:obj.contactClientId];
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersWithClientIds:filtering: %@", obj.contactClientId);
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersWithClientIds:stateOK: %@", stateOK ? @"YES" : @"NO");
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersWithClientIds:pubKeyOK: %@", pubKeyOK ? @"YES" : @"NO");
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersWithClientIds:contains: %@", contains ? @"YES" : @"NO");
        return stateOK && pubKeyOK && contains;
    }];
    if (GROUPKEY_DEBUG) NSLog(@"activeMembersWithClientIds:passed %d members", theMemberSet.count);
    return theMemberSet;
}

- (NSSet*) activeMembersNeedingKeyUpdate {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        BOOL stateOK = ([obj.state isEqualToString:@"invited"] || [obj.state isEqualToString:@"joined"]);
        BOOL pubKeyOK = obj.contactPubKeyId != nil && obj.contactHasPubKey;
        BOOL validKey = obj.hasValidGroupKey;
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersNeedingKeyUpdate:stateOK: %@", stateOK ? @"YES" : @"NO");
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersNeedingKeyUpdate:pubKeyOK: %@", pubKeyOK ? @"YES" : @"NO");
        if (GROUPKEY_DEBUG) NSLog(@"activeMembersNeedingKeyUpdate:validKey: %@", validKey ? @"YES" : @"NO");
        return stateOK && !validKey && pubKeyOK;
    }];
    if (GROUPKEY_DEBUG) NSLog(@"activeMembersNeedingKeyUpdate:passed %d members", theMemberSet.count);
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
   if (GROUPKEY_DEBUG)  NSLog(@"Group;hasGroupKey: %@", result ? @"YES" : @"NO");
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
            NSLog(@"ERROR: Group:generateNewGroupKey: hasGroupKey failed");
        }
        if (GROUPKEY_DEBUG) [self checkGroupKey];
    } else {
        NSLog(@"Group:generateNewGroupKey: can't generate (not admin), group nick %@, id %@", self.nickName, self.clientId);
        NSLog(@"%@", [NSThread callStackSymbols]);
    }
}

-(BOOL) copyKeyFromMember:(GroupMembership*)member {
    if (GROUPKEY_DEBUG) NSLog(@"Group:copyKeyFromMember: %@",member.contact.clientId);
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
            NSLog(@"ERROR: Group:copyKeyFromMember: hasGroupKey failed");
        }
        if (GROUPKEY_DEBUG) [self checkGroupKey];
        return YES;
    } else {
        NSLog(@"ERROR: Group:copyKeyFromMember: member.decryptedGroupKey failed");
    }
    return NO;
}

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
        return NO;
    }
    if (GROUPKEY_DEBUG) NSLog(@"Group:hasValidGroupKey: YES");
    return YES;
}

// return YES when member key has been updated from group, otherwise NO
// result can be used to decide if key shall be updated on server
- (BOOL)syncKeyWithMembership {
    if (GROUPKEY_DEBUG) NSLog(@"Group:syncKeyWithMember:");
    GroupMembership * ownMember = self.myGroupMembership;
    if (ownMember == nil) {
        if (GROUPKEY_DEBUG) NSLog(@"Group:syncKeyWithMember: no own member");
        return NO;
    }
    if (ownMember.hasLatestGroupKey || (ownMember.hasValidGroupKey && !self.hasValidGroupKey)) {
        if (GROUPKEY_DEBUG) NSLog(@"Group:syncKeyWithMember: copyKeyFromMember");
        [self copyKeyFromMember:ownMember];
        return NO;
    }
    if (self.hasValidGroupKey && !ownMember.hasLatestGroupKey) {
        if (GROUPKEY_DEBUG) NSLog(@"Group:syncKeyWithMember: updateKeyFromGroup");
        [ownMember updateKeyFromGroup];
        return YES;
    }
    if (GROUPKEY_DEBUG) NSLog(@"Group:syncKeyWithMember: NO");
    return NO;
}

// just for debugging purposes
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


- (BOOL) iAmAdmin {
    return [self.myGroupMembership.role isEqualToString:@"admin"];
}

- (BOOL) iJoined {
    return [self.myGroupMembership.state isEqualToString:@"joined"];
}


- (BOOL) hasKeyOnServer {
    BOOL result = self.keySupplier != nil && self.sharedKeyId != nil && self.sharedKeyIdSalt != nil && self.keyDate != nil;
    if (GROUPKEY_DEBUG) NSLog(@"Group;hasKeyOnServer: %@", result ? @"YES" : @"NO");
    return result;
}

- (BOOL) keySettingInProgress {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.keySettingInProgress;
    }];
    return theMemberSet.count > 0;
}

- (BOOL)canBeKeyMaster:(NSString*)clientID {
    NSSet * theMemberSet = [self.members objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        if ([obj.contactClientId isEqualToString:clientID]) {
            if (GROUPKEY_DEBUG) NSLog(@"canBeKeyMaster: found clientid %@", clientID);
            BOOL stateOK = ([obj.state isEqualToString:@"invited"] || [obj.state isEqualToString:@"joined"]);
            BOOL isAdmin = [obj.role isEqualToString:@"admin"];
            BOOL masterIsOffline = obj.contact.connectionStatus != nil && [obj.contact.connectionStatus isEqualToString:@"offline"];
            if (GROUPKEY_DEBUG) NSLog(@"canBeKeyMaster: stateOK %@", stateOK ? @"YES" : @"NO");
            if (GROUPKEY_DEBUG) NSLog(@"canBeKeyMaster: isAdmin %@", isAdmin ? @"YES" : @"NO");
            if (GROUPKEY_DEBUG) NSLog(@"canBeKeyMaster: masterIsOffline %@", masterIsOffline ? @"YES" : @"NO");
            return stateOK && isAdmin && !masterIsOffline;
        } else {
            return NO;
        }
    }];
    return theMemberSet.count > 0;
}

- (BOOL) hasKeyMaster {
    NSDate * estimatedServerTime = [HXOBackend.instance estimatedServerTime];
    NSTimeInterval passed = [estimatedServerTime timeIntervalSinceDate:self.keyDate];
    if (GROUPKEY_DEBUG) NSLog(@"Group;hasKeyMaster: estimatedServerTime %@, keyDate %@, passed = %f", estimatedServerTime, self.keyDate, passed);
    BOOL result = [self hasKeyOnServer] && [[HXOBackend.instance estimatedServerTime] timeIntervalSinceDate:self.keyDate] < 30.0;
    if (GROUPKEY_DEBUG) NSLog(@"Group:hasKeyMaster: maybe %@", result ? @"YES" : @"NO");
    if (result && ![self.keySupplier isEqualToString:UserProfile.sharedProfile.clientId]) {
        result = [self canBeKeyMaster:self.keySupplier];
        if (GROUPKEY_DEBUG) NSLog(@"Group:hasKeyMaster: canBeKeyMaster: %@", result ? @"YES" : @"NO");
    } else {
        if (GROUPKEY_DEBUG) NSLog(@"Group:hasKeyMaster: %@", result ? @"YES" : @"NO");
    }
    return result;
}

- (BOOL) iAmKeyMaster {
    BOOL result = self.iAmAdmin && self.hasKeyMaster && [self.keySupplier isEqualToString:UserProfile.sharedProfile.clientId];
    if (GROUPKEY_DEBUG) NSLog(@"Group:iAmKeyMaster: %@", result ? @"YES" : @"NO");
    return result;
}

- (BOOL) iCanSetKeys {
    BOOL result = (!self.hasKeyMaster || self.iAmKeyMaster) && self.iAmAdmin;
    if (GROUPKEY_DEBUG) NSLog(@"Group:iCanSetKeys: %@", result ? @"YES" : @"NO");
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
