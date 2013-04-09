//
//  Contact.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "HoccerTalkModel.h"

@class Relationship;

@interface Contact : HoccerTalkModel

@property (nonatomic, strong) NSData*        avatar;
@property (nonatomic, strong) NSString*      clientId;
@property (nonatomic, strong) NSDate*        latestMessageTime;
@property (nonatomic, strong) NSString*      nickName;
@property (nonatomic, strong) NSString*      state;

@property (nonatomic, strong) Relationship * relationship;
@property (nonatomic, strong) NSString*      currentTimeSection;
@property (nonatomic, strong) NSArray*       unreadMessages;
@property (nonatomic, strong) NSArray*       latestMessage;

@property (nonatomic, strong) NSData*       publicKey; // encrypted message crypto key

@property (nonatomic) NSString* publicKeyString; // encrypted message crypto key as b64-string


@property (nonatomic, strong) NSMutableSet* messages;

@property (readonly) UIImage* avatarImage;

- (NSString*) sectionTitleForMessageTime: (NSDate*) date;
- (SecKeyRef) getPublicKeyRef;

@end
