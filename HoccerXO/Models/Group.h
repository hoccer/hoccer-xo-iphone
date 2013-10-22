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
@property (nonatomic, retain) NSString * groupState;
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) NSSet    * members;

@property (nonatomic, retain) NSDate    * lastChangedMillis;

// @property (nonatomic, readonly) GroupMembership * myGroupMemberShip;

- (BOOL) iAmAdmin;
- (BOOL) iJoined;
- (NSSet*) otherJoinedMembers;
- (NSSet*) otherInvitedMembers;

- (NSDate *) latestMemberChangeDate; // returns the latest latestChange date of all members

@end

@interface Group (CoreDataGeneratedAccessors)

- (void)addMembersObject:(NSManagedObject *)value;
- (void)removeMembersObject:(NSManagedObject *)value;
- (void)addMembers:(NSSet *)values;
- (void)removeMembers:(NSSet *)values;

@end
