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
@property (nonatomic, retain) NSString * myRole;
@property (nonatomic, retain) NSString * myState;
@property (nonatomic, retain) NSString * groupTag;
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) NSSet    * members;

@property (nonatomic, retain) NSDate    * lastChangedMillis;

@property (nonatomic, readonly) GroupMembership * ownMemberShip;

- (BOOL) iAmAdmin;

@end

@interface Group (CoreDataGeneratedAccessors)

- (void)addMembersObject:(NSManagedObject *)value;
- (void)removeMembersObject:(NSManagedObject *)value;
- (void)addMembers:(NSSet *)values;
- (void)removeMembers:(NSSet *)values;

@end
