//
//  GroupMembership.h
//
//  Created by David Siegel on 15.05.13.
//
//

#import <Foundation/Foundation.h>
#import "HXOModel.h"

@class Contact, Group;

FOUNDATION_EXPORT NSString * const kGroupMembershipStateNone;
FOUNDATION_EXPORT NSString * const kGroupMembershipStateInvited;
FOUNDATION_EXPORT NSString * const kGroupMembershipStateJoined;
FOUNDATION_EXPORT NSString * const kGroupMembershipStateGroupRemoved;

FOUNDATION_EXPORT NSString * const kGroupMembershipRoleAdmin;
FOUNDATION_EXPORT NSString * const kGroupMembershipRoleMember;
FOUNDATION_EXPORT NSString * const kGroupMembershipRoleNearbyMember;
FOUNDATION_EXPORT NSString * const kGroupMembershipRoleWorldwideMember;


@interface GroupMembership : HXOModel

@property (nonatomic, retain) NSString * role;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) Group *group;
@property (nonatomic, retain) Contact *contact;
@property (nonatomic, retain) Contact *ownGroupContact;
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) NSData * cipheredGroupKey;
@property (nonatomic, retain) NSData * distributedCipheredGroupKey;
@property (nonatomic, retain) NSData * distributedGroupKey;
@property (nonatomic, retain) NSString * notificationPreference;


@property (nonatomic, retain) NSDate * lastChangedMillis;
@property (nonatomic, retain) NSString * cipheredGroupKeyString;
@property (nonatomic, retain) NSString * distributedCipheredGroupKeyString;
@property (nonatomic, retain) NSString * memberKeyId;

@property (nonatomic, retain) NSData   * sharedKeyId;
@property (nonatomic, retain) NSData   * sharedKeyIdSalt;

@property (nonatomic, retain) NSString * sharedKeyIdString;
@property (nonatomic, retain) NSString * sharedKeyIdSaltString;

@property (nonatomic, retain) NSString * keySupplier;
@property (nonatomic, retain) NSDate * sharedKeyDate;
@property (nonatomic, retain) NSDate * sharedKeyDateMillis;

@property (nonatomic) BOOL keySettingInProgress;

- (NSData *) calcCipheredGroupKey;
- (NSData *) decryptedGroupKey;
- (BOOL) hasCipheredGroupKey;

- (BOOL) isOwnMembership;

- (NSString*)contactClientId;
- (NSString*)contactPubKeyId;
- (BOOL)contactHasPubKey;

- (BOOL)isJoined;
- (BOOL)isInvited;
- (BOOL)isStateNone;
- (BOOL)isGroupRemoved;
- (BOOL)isMember;
- (BOOL)isNearbyMember;
- (BOOL)isWorldwideMember;
- (BOOL)isAdmin;
- (BOOL)hasActiveRole;

@end
