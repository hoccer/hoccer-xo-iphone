//
//  Contact.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Contact.h"
#import "Crypto.h"
#import "NSData+Base64.h"
#import "CCRSA.h"
#import "HXOUserDefaults.h"
#import "HXOBackend.h" // for date conversion

#import "Group.h"
#import "GroupMembership.h"
#import "AppDelegate.h"

// const float kTimeSectionInterval = 2 * 60;

#define TRACE_CONTACT_FAULTING  NO

@implementation Contact

@dynamic type;
@dynamic avatar;
@dynamic avatarURL;
@dynamic avatarUploadURL;
@dynamic clientId;
@dynamic latestMessageTime;
@dynamic nickName;
@dynamic alias;
@dynamic status;
@dynamic unreadMessages;
@dynamic latestMessage;
@dynamic publicKey;
@dynamic verifiedKey;
@dynamic publicKeyId;
@dynamic connectionStatus;
@dynamic presenceLastUpdated;
@dynamic notificationPreference;

@dynamic messages;
@dynamic deliveriesSent;
@dynamic deliveriesReceived;
@dynamic groupMemberships;
@dynamic nickNameWithStatus;
@dynamic myGroupMembership;
@dynamic savedMessageBody;
@dynamic savedAttachments;
@dynamic savedAttachment;

@dynamic lastUpdateReceived;

@dynamic groupMembershipList;

@synthesize rememberedLastVisibleChatCell;
@synthesize deletedObject;

NSString * const kRelationStateNone        = @"none";
NSString * const kRelationStateFriend      = @"friend";
NSString * const kRelationStateBlocked     = @"blocked";
NSString * const kRelationStateInvited     = @"invited";
NSString * const kRelationStateInvitedMe   = @"invitedMe";
NSString * const kRelationStateGroupFriend = @"groupfriend";
NSString * const kRelationStateInternalKept= @"kept";

NSString * const kPresenceStateOnline = @"online";
NSString * const kPresenceStateOffline = @"offline";
NSString * const kPresenceStateBackground = @"background";
NSString * const kPresenceStateTyping = @"typing";


@dynamic publicKeyString;
@dynamic relationshipState;
@dynamic relationshipUnblockState;
@dynamic relationshipLastChanged;
@dynamic relationshipLastChangedMillis;

@dynamic presenceLastUpdatedMillis;
@dynamic keyLength;

- (NSNumber*) relationshipLastChangedMillis {
    return [HXOBackend millisFromDate:self.relationshipLastChanged];
}

- (void) setRelationshipLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.relationshipLastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSNumber*) presenceLastUpdatedMillis {
    return [HXOBackend millisFromDate:self.presenceLastUpdated];
}

- (void) setPresenceLastUpdatedMillis:(NSNumber*) milliSecondsSince1970 {
    self.presenceLastUpdated = [HXOBackend dateFromMillis:milliSecondsSince1970];
}


@synthesize avatarImage = _avatarImage;

- (UIImage*) avatarImage {
    if (_avatarImage == nil) {
        _avatarImage = self.avatar == nil ? nil : [UIImage imageWithData: self.avatar];
    }
    return _avatarImage;
}

- (void) setAvatar:(NSData *)avatar {
    [self willChangeValueForKey: @"avatar"];
    [self willChangeValueForKey: @"avatarImage"];
    [self setPrimitiveValue: avatar forKey: @"avatar"];
    _avatarImage = nil;
    self.avatarUploadURL = nil;
    [self didChangeValueForKey: @"avatar"];
    [self didChangeValueForKey: @"avatarImage"];
}

- (void) setAvatarImage:(UIImage *)avatarImage {
    [self willChangeValueForKey: @"avatar"];
    [self willChangeValueForKey: @"avatarImage"];
    _avatarImage = avatarImage;
    self.avatarUploadURL = nil; // clear Upload URL so we know if we have to upload it in case of group avatars
    float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
    [self setPrimitiveValue: UIImageJPEGRepresentation( _avatarImage, photoQualityCompressionSetting/10.0) forKey: @"avatar"];
    [self didChangeValueForKey: @"avatar"];
    [self didChangeValueForKey: @"avatarImage"];
}

-(NSString*) publicKeyString {
    return [self.publicKey asBase64EncodedString];
}

-(void) setPublicKeyString:(NSString*) theB64String {
    self.publicKey = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSNumber*) keyLength {
    return @([CCRSA getPublicKeySize: self.publicKey]);
}

- (SecKeyRef) getPublicKeyRef {
    CCRSA * rsa = [CCRSA sharedInstance];
    SecKeyRef myResult = [rsa getPeerKeyRef:self.clientId];
    if (myResult == nil) {
        // store public key from contact in key store
        if (self.publicKey != nil) {
            [rsa addPublicPeerKey: self.publicKeyString withPeerName: self.clientId];
        }
    } else {
        // check if correct key id in key store
        if (self.publicKey == nil) {
            NSLog(@"ERROR: Contact:getPublicKeyRef: public key in keystore but not in database for client id %@, nick %@", self.clientId, self.nickName);
            return nil;
        }
        NSData * myKeyBits = [rsa getKeyBitsForPeerRef:self.clientId];
        if (![myKeyBits isEqualToData:self.publicKey]) {
            [rsa removePeerPublicKey:self.clientId];
            [rsa addPublicPeerKey: self.publicKeyString withPeerName: self.clientId];
            // NSLog(@"Contact:getPublicKeyRef: changed public key of %@", self.nickName);
        }
    }
    myResult = [rsa getPeerKeyRef:self.clientId];
    if (myResult == nil) {
        NSLog(@"ERROR: Contact:getPublicKeyRef: failed for client id %@, nick %@", self.clientId, self.nickName);
    }
    return myResult;
}

- (BOOL) hasPublicKey {
    if (![HXOBackend isInvalid:self.publicKey]) {
        //NSLog(@"Contact hasPublicKey YES, id %@", self.clientId);
        return YES;
    } else {
        //NSLog(@"Contact hasPublicKey NO, id %@ ", self.clientId);
        return NO;
    }
}

- (NSString*) nickNameOrAlias {
    if (self.isGroup && (self.isNearby || self.isWorldwide)) {
        if (self.isKeptGroup) {
            return self.isNearby ? NSLocalizedString(@"group_name_nearby_kept", nil) : NSLocalizedString(@"group_name_worldwide_kept", nil);
        } else {
            Group * group = (Group*)self;
            NSUInteger otherCount = group.otherJoinedMembers.count;

            if (otherCount > 0) {
                return self.isNearby ? [NSString stringWithFormat:NSLocalizedString(@"group_name_nearby_active", nil), otherCount]
                : [NSString stringWithFormat:NSLocalizedString(@"group_name_worldwide_active", nil), otherCount];
            } else {
                return self.isNearby ? NSLocalizedString(@"group_name_nearby_empty", nil) : NSLocalizedString(@"group_name_worldwide_empty", nil);
            }
        }
    }
    
    if (self.alias != nil && self.alias.length > 0) {
        return self.alias;
    } else {
        // NSLog(@"self = %@, nickname = %@", self, self.nickName);
        return self.nickName;
    }
}

- (NSString*) nickNameWithStatus {
    NSString * statusString = nil;
    if (self.isInvited) {
        statusString = @"✪";
    } else if (self.invitedMe) {
        statusString = @"★";
    } else if (self.isKept) {
        statusString = @"❄";
    } else if (self.isBlocked) {
        statusString = @""; // We have already UI for blocked state
    } else if (self.isGroup && [(Group*)self otherJoinedMembers].count == 0) {
        statusString = @"◦";
    } else if (!self.isGroup && self.isNotRelated) {
        statusString = @"✢";
    } else if (!self.isGroup && self.isGroupFriend) {
        if (self.isWorldwideContact) {
            if (self.isSuspendedWorldwideContact) {
                statusString = @"🌑";
            } else {
                statusString = @"🌐";
            }
        } else {
            statusString = @"❖";
        }
    } else if (self.isTyping) {
        //statusString = @"✍"; //writing hand
        //statusString = @"✎"; //Pen
        //statusString = @"➽"; //arrow
        statusString = @"↵"; //arrow
    } else if ( self.isBackground) {
        statusString = @""; // should be yellow online indicator
    } else if ( ! self.connectionStatus || self.isConnected || self.isOffline) {
        statusString = nil;
    } else {
        // show special connection status
        statusString = [NSString stringWithFormat:@"[%@]", self.connectionStatus];
    }

    NSString * name = self.nickNameOrAlias;
    return statusString ? [NSString stringWithFormat: @"%@ %@", name, statusString] : name;
}

- (BOOL) isGroup {
    return [@"Group" isEqualToString:self.type];
}

- (BOOL) isBlocked {
    return [kRelationStateBlocked isEqualToString: self.relationshipState];
}

- (BOOL) isInvited {
    return [kRelationStateInvited isEqualToString: self.relationshipState];
}

- (BOOL) invitedMe {
    return [kRelationStateInvitedMe isEqualToString: self.relationshipState];
}
    
- (BOOL) isInvitable {
    return !self.isFriend && !self.invitedMe && !self.isInvited;
}

- (BOOL) isFriend {
    return [kRelationStateFriend isEqualToString: self.relationshipState];
}

- (BOOL) isDirectlyRelated {
    return self.isFriend || self.isInvited || self.invitedMe || self.isBlocked;
}

- (BOOL) isGroupFriend {
    return [kRelationStateGroupFriend isEqualToString: self.relationshipState];
}

- (BOOL) isKeptRelation {
    return [kRelationStateInternalKept isEqualToString: self.relationshipState];
}
- (BOOL) isKeptGroup {
    return [kRelationStateInternalKept isEqualToString: self.myGroupMembership.group.groupState];
}

- (BOOL) isKept {
    if (self.isGroup) {
        return self.isKeptGroup || self.isKeptRelation;
    } else {
        return self.isKeptRelation;
    }
}

- (BOOL) isNotRelated {
    return self.relationshipState == nil || [kRelationStateNone isEqualToString: self.relationshipState];
}

- (BOOL) isOffline {
    return self.connectionStatus == nil || [ kPresenceStateOffline isEqualToString: self.connectionStatus];
}

- (BOOL) isBackground {
    return [kPresenceStateBackground isEqualToString: self.connectionStatus];
}

- (BOOL) isOnline {
    return [kPresenceStateOnline isEqualToString: self.connectionStatus];
}

- (BOOL) isTyping {
    return [kPresenceStateTyping isEqualToString: self.connectionStatus];
}

- (BOOL) isPresent {
    return self.isOnline || self.isTyping;
}

- (BOOL) isConnected {
    return self.isPresent || self.isBackground;
}

- (BOOL) isNearbyContact {
    return self.isMemberinNearbyGroup;
}

- (BOOL) isWorldwideContact {
    return self.isMemberinWorldwideGroup;
}

- (BOOL) isSuspendedWorldwideContact {
    return self.isSuspendedMemberinWorldwideGroup;
}

- (BOOL) isNearby {
    if (self.isGroup) {
        return [(Group*)self isNearbyGroup];
    } else {
        return self.isNearbyContact;
    }
}

- (BOOL) isWorldwide {
    if (self.isGroup) {
        return [(Group*)self isWorldwideGroup];
    } else {
        return self.isWorldwideContact;
    }
}

- (BOOL)hasNotificationsEnabled {
    return ![@"disabled" isEqualToString: self.notificationPreference];
}

- (BOOL) isMemberinNearbyGroup {
    NSSet * thGroupSet = [self.groupMemberships objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.group.isNearbyGroup && obj.group.isExistingGroup;
    }];
    return thGroupSet.count > 0;
}


- (BOOL) isMemberinWorldwideGroup {
    NSSet * thGroupSet = [self.groupMemberships objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.group.isWorldwideGroup && obj.group.isExistingGroup;
    }];
    return thGroupSet.count > 0;
}

- (BOOL) isSuspendedMemberinWorldwideGroup {
    NSSet * thGroupSet = [self.groupMemberships objectsPassingTest:^BOOL(GroupMembership* obj, BOOL *stop) {
        return obj.group.isWorldwideGroup && obj.group.isExistingGroup && [obj.state isEqualToString:@"suspended"];
    }];
    return thGroupSet.count > 0;
}

- (NSString*) groupMembershipList {
    // NSLog(@"groupMembershipList called on contact %@",self);
    NSMutableArray * groups = [[NSMutableArray alloc] init];

    [groups addObject: @""];
    
    [self.groupMemberships enumerateObjectsUsingBlock:^(GroupMembership* member, BOOL *stop) {
        if (![member.contact isEqual: member.group]) {
            if (member.group.nickName != nil) {
                [groups addObject: member.group.nickName];
            } else {
                [groups addObject: @"?"];
            }
        } else {
            [groups addObject: @"<is group itself>"];
        }
    }];
    groups[0]=[NSString stringWithFormat:@"(%@)", @(groups.count - 1)];
    if (groups.count == 0) {
        return @"-";
    }
    // NSLog(@"groupMembershipList returns %@",[groups componentsJoinedByString:@", "]);
    return [groups componentsJoinedByString:@", "];
}


- (void) setGroupMembershipList:(NSString*)theList {
    NSLog(@"WARNING: setter called on groupMembershipList, value = %@",theList);
}

-(void)prepareForDeletion {
    if ([AppDelegate.instance.currentObjectContext isEqual: AppDelegate.instance.mainObjectContext]) {
        // NSLog(@"Contact:prepareForDeletion type=%@ nick=%@ id = %@", [self class], self.nickName, self.clientId);
        self.deletedObject = YES;
    }
}

- (void) willTurnIntoFault {
    if (TRACE_CONTACT_FAULTING) NSLog(@"contact will turn into fault: %@", self.nickName);
}

-(void)dealloc {
    // NSLog(@"dealloc %@", [self class]);
}

- (NSDictionary*) rpcKeys {
    return @{ @"state"     : @"relationshipState",
              @"unblockState": @"relationshipUnblockState",
              @"lastChanged": @"relationshipLastChangedMillis",
              @"notificationPreference" : @"notificationPreference"
              };
}

- (id) valueForUndefinedKey:(NSString *)key {
    if ([key isEqualToString: @"password"]) {
        return nil;
    }
    return @"<undefined>";
    //return [super valueForUndefinedKey: key];
}

@end
