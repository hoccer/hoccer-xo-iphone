//
//  GroupMembership.m
//  QRCodeEncoderObjectiveCAtGithub
//
//  Created by David Siegel on 15.05.13.
//
//

#import "GroupMembership.h"
#import "Contact.h"
#import "Group.h"
#import "HXOBackend.h"
#import "CCRSA.h"
#import "NSData+Base64.h"
#import "Crypto.h"
#import "UserProfile.h"

NSString * const kGroupMembershipStateNone          = @"none";
NSString * const kGroupMembershipStateInvited       = @"invited";
NSString * const kGroupMembershipStateJoined        = @"joined";
NSString * const kGroupMembershipStateGroupRemoved  = @"groupRemoved";
NSString * const kGroupMembershipStateSuspended     = @"suspended";

NSString * const kGroupMembershipRoleAdmin          = @"admin";
NSString * const kGroupMembershipRoleMember         = @"member";
NSString * const kGroupMembershipRoleNearbyMember   = @"nearbyMember";
NSString * const kGroupMembershipRoleWorldwideMember   = @"worldwideMember";

@implementation GroupMembership

@dynamic role;
@dynamic state;
@dynamic group;
@dynamic contact;
@dynamic ownGroupContact;
@dynamic lastChanged;
@dynamic cipheredGroupKey;
@dynamic distributedCipheredGroupKey;
@dynamic distributedGroupKey;
@dynamic memberKeyId;
@dynamic keySupplier;

@dynamic cipheredGroupKeyString;
@dynamic distributedCipheredGroupKeyString;
@dynamic lastChangedMillis;
@dynamic sharedKeyId;
@dynamic sharedKeyIdSalt;

@dynamic sharedKeyIdString;
@dynamic sharedKeyIdSaltString;

@dynamic sharedKeyDate;
@dynamic sharedKeyDateMillis;

@dynamic notificationPreference;

@synthesize keySettingInProgress;

#define GROUPKEY_DEBUG NO

#if 0
- (void)didChangeValueForKey:(NSString *)key {
    [super didChangeValueForKey:key];
    NSLog(@"Groupmembership changed for key '%@'",key);

    if ([key isEqualToString:@"contact"]) {
        if (self.contact == nil) {
            NSLog(@"Groupmembership contact changed to nil: %@",[NSThread callStackSymbols]);
        }
    }
}
#endif

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSNumber*) sharedKeyDateMillis {
    return [HXOBackend millisFromDate:self.sharedKeyDate];
}

- (void) setSharedKeyDateMillis:(NSNumber*) milliSecondsSince1970 {
    self.sharedKeyDate = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

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

- (void) setNotificationPreference:(NSString *)preference {
    
    [self willChangeValueForKey:@"notificationPreference"];
    [self setPrimitiveValue: preference forKey: @"notificationPreference"];
    [self didChangeValueForKey:@"notificationPreference"];
    
    if (self.isOwnMembership) {
        if (self.group != nil) {
            self.group.notificationPreference = preference;
        } else {
            NSLog(@"#Warning: GroupMembership: can not set notification preference on own group, own group not yet there");
        }
    }
}

- (NSString *) notificationPreference {
    if (self.isOwnMembership) {
        if (self.group != nil) {
            return self.group.notificationPreference;
        } else {
            NSLog(@"#Warning: can not get notification preference from own group, own group not yet there");
        }
    }
    return [self primitiveValueForKey:@"notificationPreference"];
}


- (BOOL)isJoined {
    return [kGroupMembershipStateJoined isEqualToString: self.state];
}

- (BOOL)isInvited {
    return [kGroupMembershipStateInvited isEqualToString: self.state];
}

- (BOOL)isStateNone {
    return [kGroupMembershipStateNone isEqualToString: self.state];
}

- (BOOL)isSuspended {
    return [kGroupMembershipStateSuspended isEqualToString: self.state];
}

- (BOOL)isGroupRemoved {
    return [kGroupMembershipStateGroupRemoved isEqualToString: self.state];
}

- (BOOL)isMember {
    return [kGroupMembershipRoleMember isEqualToString: self.role];
}

- (BOOL)isNearbyMember {
    return [kGroupMembershipRoleNearbyMember isEqualToString: self.role];
}

- (BOOL)isWorldwideMember {
    return [kGroupMembershipRoleWorldwideMember isEqualToString: self.role];
}

- (BOOL)isAdmin {
    return [kGroupMembershipRoleAdmin isEqualToString: self.role];
}

- (BOOL)hasActiveRole {
    return self.isMember || self.isAdmin || self.isNearbyMember || self.isWorldwideMember;
}

- (NSData *) calcCipheredGroupKey {
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.contact getPublicKeyRef];
    CCRSA * rsa = [CCRSA sharedInstance];
    //NSLog(@"self.group.groupKey=%@",[self.group.groupKey asBase64EncodedString]);
    return [rsa encryptWithKey:myReceiverKey plainData:self.group.groupKey];
}

- (BOOL) hasCipheredGroupKey {
    if (self.cipheredGroupKey != nil && self.cipheredGroupKey.length > 0) {
        if (GROUPKEY_DEBUG) NSLog(@"hasCipheredGroupKey: YES");
        return YES;
    }
    if (GROUPKEY_DEBUG) NSLog(@"hasCipheredGroupKey: NO");
    return NO;
}

- (BOOL) isOwnMembership {
    return [self.group isEqual:self.contact];
}

- (NSString*)contactClientId {
    if (self.isOwnMembership) {
        return UserProfile.sharedProfile.clientId;
    } else {
        return self.contact.clientId;
    }
}

- (NSString*)contactPubKeyId {
    if (self.isOwnMembership) {
        return UserProfile.sharedProfile.publicKeyId;
    } else {
        return self.contact.publicKeyId;
    }
}

- (BOOL)contactHasPubKey {
    if (self.isOwnMembership) {
        BOOL result = UserProfile.sharedProfile.hasPublicKey;
        if (GROUPKEY_DEBUG) NSLog(@"Member(selfcontact):contactHasPubKey: %@", result ? @"YES" : @"NO");
        return result;
    } else {
        BOOL result = self.contact.hasPublicKey;
        if (GROUPKEY_DEBUG) NSLog(@"Member(%@):contactHasPubKey: %@", self.contact.clientId, result ? @"YES" : @"NO");
        return result;
    }
}

- (NSData *) decryptedGroupKey {
    if (![self.group isEqual:self.contact]) {
        NSLog(@"ERROR:Group key won't be encrypted for me - must not call this function on other group members except me, contact nick=%@ contact.clientId = %@, group nick=%@, group.clientId = %@", self.contact.nickName, self.contact.clientId ,self.group.nickName, self.group.clientId);
        NSLog(@"%@",[NSThread callStackSymbols]);
        return nil;
    }
    if (self.cipheredGroupKey == nil || self.cipheredGroupKey.length == 0) {
        NSLog(@"ERROR:No Group key for me yet");
        return nil;
    }
    return [self decryptGroupKey:self.cipheredGroupKey withMemberKeyId:self.memberKeyId];
}

- (NSData *)decryptGroupKey:(NSData*)cipheredGroupKey withMemberKeyId:(NSString*)memberKeyId {
    CCRSA * rsa = [CCRSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRefForPublicKeyIdString:memberKeyId];
    if (myPrivateKeyRef == NULL) {
        NSLog(@"ERROR: decryptGroupKey: no private key for memberKeyId %@",memberKeyId);
        return nil;
    }
    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:cipheredGroupKey];
    if ([HXOBackend isInvalid:theClearTextKey]) {
        NSLog(@"ERROR: decryptGroupKey: decryption yielded no valid key despite of memberKeyId was fine");
        return nil;
    }
    return theClearTextKey;
    
}


-(NSString*) cipheredGroupKeyString {
    return [self.cipheredGroupKey asBase64EncodedString];
}

-(void) setCipheredGroupKeyString:(NSString*) theB64String {
    self.cipheredGroupKey = [NSData dataWithBase64EncodedString:theB64String];
}

-(NSString*) distributedCipheredGroupKeyString {
    return [self.distributedCipheredGroupKey asBase64EncodedString];
}

-(void) setDistributedCipheredGroupKeyString:(NSString*) theB64String {
    self.distributedCipheredGroupKey = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSDictionary*) rpcKeys {
    return @{ @"role"         : @"role",
              @"state"        : @"state",
              @"lastChanged"  : @"lastChangedMillis",
              @"encryptedGroupKey": @"cipheredGroupKeyString",
              @"memberKeyId"  : @"memberKeyId",
              @"sharedKeyId"  : @"sharedKeyIdString",
              @"sharedKeyIdSalt" : @"sharedKeyIdSaltString",
              @"sharedKeyDate"  : @"sharedKeyDateMillis",
              @"keySupplier"  : @"keySupplier",
              @"notificationPreference" : @"notificationPreference"
              };
}

@end

//public class TalkGroupMember {
//    public static final String ROLE_NONE = "none";
//    public static final String ROLE_ADMIN = "admin";
//    public static final String ROLE_MEMBER = "member";
//
//  String groupId;
//  String clientId;
//  String role;
//  String state;
//  String memberKeyId;
//  String encryptedGroupKey;
//  Date lastChanged;
//}