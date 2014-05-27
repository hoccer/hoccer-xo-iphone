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

// const float kTimeSectionInterval = 2 * 60;

@implementation Contact

@dynamic type;
@dynamic avatar;
@dynamic avatarURL;
@dynamic avatarUploadURL;
@dynamic clientId;
@dynamic latestMessageTime;
@dynamic nickName;
@dynamic status;
@dynamic isNearbyTag;

// @dynamic currentTimeSection;
@dynamic unreadMessages;
@dynamic latestMessage;
@dynamic publicKey;
@dynamic verifiedKey;
@dynamic publicKeyId;
@dynamic connectionStatus;
@dynamic presenceLastUpdated;

@dynamic messages;
@dynamic deliveriesSent;
@dynamic deliveriesReceived;
@dynamic groupMemberships;
@dynamic nickNameWithStatus;
@dynamic myGroupMembership;

@dynamic lastUpdateReceived;

@dynamic groupMembershipList;

@synthesize rememberedLastVisibleChatCell;
@synthesize friendMessageShown;

NSString * const kRelationStateNone        = @"none";
NSString * const kRelationStateFriend      = @"friend";
NSString * const kRelationStateBlocked     = @"blocked";
NSString * const kRelationStateGroupFriend = @"groupfriend";
NSString * const kRelationStateKept        = @"kept";

@dynamic publicKeyString;
@dynamic relationshipState;
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
    return [NSNumber numberWithInt:[CCRSA getPublicKeySize: self.publicKey]];
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



- (NSString*) nickNameWithStatus {
    if (self.isKept) {
        return [NSString stringWithFormat:@"%@ ❌", self.nickName];
    }
    if (self.isBlocked) {
        return self.nickName;
    }
    if (self.isGroup) {
        Group * group = (Group*)self;
        if ([[group otherJoinedMembers] count] == 0) {
            return [NSString stringWithFormat:@"%@ ⭕", self.nickName];
        }
    }
    if (self.isNotRelated) {
        return [NSString stringWithFormat:@"%@ ❓", self.nickName];
    }
    NSString * name = self.nickName;
    if (self.isGroupFriend) {
        name = [NSString stringWithFormat:@"%@ 🔗", self.nickName];
    }
    if ( self.isTyping) {
        name = [NSString stringWithFormat:@"%@ 💬", self.nickName];
    }
    if ( self.isBackground) {
        name = [NSString stringWithFormat:@"%@ 💤", self.nickName];
    }
    if ( ! self.connectionStatus || self.isConnected || self.isOffline) {
        return name;
    } else {
        // show special connection status
        return [NSString stringWithFormat:@"%@ [%@]", name, self.connectionStatus];
    }
}

- (BOOL) isGroup {
    return [@"Group" isEqualToString:self.type];
}

- (BOOL) isBlocked {
    return [kRelationStateBlocked isEqualToString: self.relationshipState];
}

- (BOOL) isFriend {
    return [kRelationStateFriend isEqualToString: self.relationshipState];
}

- (BOOL) isGroupFriend {
    return [kRelationStateGroupFriend isEqualToString: self.relationshipState];
}

- (BOOL) isKeptRelation {
    return [kRelationStateKept isEqualToString: self.relationshipState];
}
- (BOOL) isKeptGroup {
    return [kRelationStateKept isEqualToString: self.myGroupMembership.group.groupState];
}

- (BOOL) isKept {
    if (self.isGroup) {
        return self.isKeptGroup || self.isKeptRelation;
    } else {
        return self.isKeptRelation;
    }
}

- (BOOL) isNotRelated {
    return [kRelationStateNone isEqualToString: self.relationshipState];
}

- (BOOL) isOffline {
    return self.connectionStatus == nil || [ @"offline" isEqualToString: self.connectionStatus];
}

- (BOOL) isBackground {
    return [@"background" isEqualToString: self.connectionStatus];
}

- (BOOL) isOnline {
    return [@"online" isEqualToString: self.connectionStatus];
}

- (BOOL) isTyping {
    return [@"typing" isEqualToString: self.connectionStatus];
}

- (BOOL) isPresent {
    return self.isOnline || self.isTyping;
}

- (BOOL) isConnected {
    return self.isPresent || self.isBackground;
}

- (BOOL) isNearbyContact {
    return [@"YES" isEqualToString: self.isNearbyTag];
}

- (BOOL) isNearby {
    if (self.isGroup) {
        return [(Group*)self isNearbyGroup];
    } else {
        return self.isNearbyContact;
    }
}

-(void) updateNearbyFlag {
    NSSet * myMemberships = self.groupMemberships;
    BOOL isNearby = NO;
    for (GroupMembership * memberShip in myMemberships) {
        if (memberShip.group.isExistingGroup && memberShip.group.isNearbyGroup) {
            isNearby = YES;
        }
    }
    if (isNearby != self.isNearbyContact) {
        if (isNearby) {
            self.isNearbyTag = @"YES";
        } else {
            self.isNearbyTag = nil;
        }
    }
}

- (NSString*) groupMembershipList {
    NSLog(@"groupMembershipList called on contact %@",self);
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
    groups[0]=[NSString stringWithFormat:@"(%d)", groups.count-1];
    if (groups.count == 0) {
        return @"-";
    }
    NSLog(@"groupMembershipList returns %@",[groups componentsJoinedByString:@", "]);
    return [groups componentsJoinedByString:@", "];
}


- (void) setGroupMembershipList:(NSString*)theList {
    NSLog(@"WARNING: setter called on groupMembershipList, value = %@",theList);
}


- (NSDictionary*) rpcKeys {
    return @{ @"state"     : @"relationshipState",
              @"lastChanged": @"relationshipLastChangedMillis",
              };
}

- (id) valueForUndefinedKey:(NSString *)key {
    if ([key isEqualToString: @"password"]) {
        return nil;
    }
    return [super valueForUndefinedKey: key];
}

@end
