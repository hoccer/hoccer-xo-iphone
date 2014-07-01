//
//  GroupInStatuNascendi.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "GroupInStatuNascendi.h"

#import "DatasheetController.h"
#import "GroupMembership.h"
#import "Contact.h"

@implementation GroupInStatuNascendi

@synthesize deletedObject;

@synthesize members = _members;
- (NSMutableArray*) members {
    if ( ! _members) {
        _members = [NSMutableArray array];
        [_members addObject: self];
    }
    return _members;
}

- (BOOL) iAmAdmin { return YES; }

//
-(void) addGroupMemberContacts:(NSSet *)newMembers {
    for (GroupMembership * member in newMembers) {
        NSLog(@"adding member:%@", member.contact.nickName);
        [self.members addObject:member.contact];
    }
}


@end
