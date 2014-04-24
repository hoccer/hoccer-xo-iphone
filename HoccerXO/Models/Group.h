//
//  Group.h
//  HoccerXO
//
//  Created by David Siegel on 15.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Contact.h"

@class GroupMembership;

@interface Group : Contact

@property (nonatomic, retain) NSData   * groupKey;
@property (nonatomic, retain) NSString * groupTag;
@property (nonatomic, retain) NSString * groupType;
@property (nonatomic, retain) NSString * keySupplier;
@property (nonatomic, retain) NSDate   * keyDate;
@property (nonatomic, retain) NSString * groupState;
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) NSSet    * members;

@property (nonatomic, retain) NSData   * sharedKeyId;
@property (nonatomic, retain) NSData   * sharedKeyIdSalt;

@property (nonatomic, retain) NSString * sharedKeyIdString;
@property (nonatomic, retain) NSString * sharedKeyIdSaltString;

@property (nonatomic, retain) NSNumber    * lastChangedMillis;
@property (nonatomic, retain) NSNumber    * keyDateMillis;

@property  unsigned updatesRefused;

// @property (nonatomic, readonly) GroupMembership * myGroupMemberShip;

- (BOOL) iAmAdmin;
- (BOOL) iJoined;
- (NSSet*) otherJoinedMembers;
- (NSSet*) otherInvitedMembers;

- (NSDate *) latestMemberChangeDate; // returns the latest latestChange date of all members

- (BOOL) hasGroupKey;
- (BOOL) hasValidGroupKey;
- (void) generateNewGroupKey;
- (BOOL) copyKeyFromMember:(GroupMembership*)member;
- (BOOL) checkGroupKey;

- (BOOL) hasKeyOnServer;
- (BOOL) hasKeyMaster;
- (BOOL) iAmKeyMaster;
- (BOOL) iCanSetKeys;

- (BOOL) keySettingInProgress;


- (BOOL)syncKeyWithMembership;

- (NSSet*) activeMembersWithClientIds:(NSArray*)clientIds;
- (NSSet*) activeMembersWithClientIdsAndMissingKey:(NSArray*)clientIds;

@end

@interface Group (CoreDataGeneratedAccessors)

- (void)addMembersObject:(NSManagedObject *)value;
- (void)removeMembersObject:(NSManagedObject *)value;
- (void)addMembers:(NSSet *)values;
- (void)removeMembers:(NSSet *)values;

@end
