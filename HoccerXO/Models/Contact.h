//
//  Contact.h
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "HXOModel.h"

@class GroupMembership;

FOUNDATION_EXPORT NSString * const kRelationStateNone;
FOUNDATION_EXPORT NSString * const kRelationStateFriend;
FOUNDATION_EXPORT NSString * const kRelationStateBlocked;

@interface Contact : HXOModel

@property (nonatomic, strong) NSString*      type;
@property (nonatomic, strong) NSData*        avatar;
@property (nonatomic, strong) NSString*      avatarURL;
@property (nonatomic, strong) NSString*      avatarUploadURL;
@property (nonatomic, strong) NSString*      clientId;
@property (nonatomic, strong) NSDate*        latestMessageTime;
@property (nonatomic, strong) NSDate*        presenceLastUpdated;
@property (nonatomic, strong) NSString*      nickName;
@property (nonatomic, strong) NSString*      status;
@property (nonatomic, strong) NSString*      phoneNumber;
@property (nonatomic, strong) NSString*      mailAddress;
@property (nonatomic, strong) NSString*      twitterName;
@property (nonatomic, strong) NSString*      facebookName;
@property (nonatomic, strong) NSString*      googlePlusName;
@property (nonatomic, strong) NSString*      githubName;
@property (nonatomic, retain) GroupMembership * myGroupMembership;

// @property (nonatomic, strong) NSDate*        currentTimeSection;
@property (nonatomic, strong) NSArray*       unreadMessages;
@property (nonatomic, strong) NSArray*       latestMessage;

@property (nonatomic, strong) NSData*       publicKey; // public key of this contact
@property (nonatomic, strong) NSString*     publicKeyId; // id of public key
@property (nonatomic, strong) NSString*     connectionStatus;

@property (nonatomic, retain) NSString * relationshipState;
@property (nonatomic, retain) NSDate * relationshipLastChanged;

@property (nonatomic,strong) NSNumber * relationshipLastChangedMillis;
@property (nonatomic,strong) NSNumber * presenceLastUpdatedMillis;

@property (nonatomic, strong) NSIndexPath * rememberedLastVisibleChatCell;


@property (nonatomic,strong) NSString* publicKeyString; // b64-string


@property (nonatomic, strong) NSMutableSet* messages;
@property (nonatomic, strong) NSMutableSet* groupMemberships;
@property (readonly) NSString * nickNameWithStatus;

@property (nonatomic, strong) UIImage* avatarImage;

+ (NSString*) sectionTitleForMessageTime: (NSDate*) date;

- (SecKeyRef) getPublicKeyRef;
- (SecKeyRef) getPublicKeyRefRSA;
- (SecKeyRef) getPublicKeyRefEC;

@end
