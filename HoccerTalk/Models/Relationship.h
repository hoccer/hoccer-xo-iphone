//
//  Relationship.h
//  HoccerTalk
//
//  Created by David Siegel on 09.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HoccerTalkModel.h"

@class Contact;

FOUNDATION_EXPORT NSString * const kRelationStateNone;
FOUNDATION_EXPORT NSString * const kRelationStateFriend;
FOUNDATION_EXPORT NSString * const kRelationStateBlocked;


@interface Relationship : HoccerTalkModel

@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) Contact *contact;

@end
