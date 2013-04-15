//
//  Contact.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

#import "HoccerTalkModel.h"

FOUNDATION_EXPORT NSString * const kRelationStateNone;
FOUNDATION_EXPORT NSString * const kRelationStateFriend;
FOUNDATION_EXPORT NSString * const kRelationStateBlocked;

@interface Contact : HoccerTalkModel

@property (nonatomic, strong) NSData*        avatar;
@property (nonatomic, strong) NSString*      avatarURL;
@property (nonatomic, strong) NSString*      clientId;
@property (nonatomic, strong) NSDate*        latestMessageTime;
@property (nonatomic, strong) NSString*      nickName;
@property (nonatomic, strong) NSString*      status;
@property (nonatomic, strong) NSString*      phoneNumber;
@property (nonatomic, strong) NSString*      mailAddress;
@property (nonatomic, strong) NSString*      twitterName;
@property (nonatomic, strong) NSString*      facebookName;
@property (nonatomic, strong) NSString*      googlePlusName;
@property (nonatomic, strong) NSString*      githubName;

@property (nonatomic, strong) NSString*      currentTimeSection;
@property (nonatomic, strong) NSArray*       unreadMessages;
@property (nonatomic, strong) NSArray*       latestMessage;

@property (nonatomic, strong) NSData*       publicKey; // public key of this contact
@property (nonatomic, strong) NSString*     publicKeyId; // id of public key

@property (nonatomic, retain) NSString * relationshipState;
@property (nonatomic, retain) NSDate * relationshipLastChanged;

@property (nonatomic) NSString* publicKeyString; // b64-string


@property (nonatomic, strong) NSMutableSet* messages;

@property (readonly) UIImage* avatarImage;
@property (readonly, strong) NSString* avatarImageCachedURL;

- (NSString*) sectionTitleForMessageTime: (NSDate*) date;
- (SecKeyRef) getPublicKeyRef;

@end
