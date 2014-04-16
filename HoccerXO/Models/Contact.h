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
#import "HXOClientProtocol.h"

@class GroupMembership;

FOUNDATION_EXPORT NSString * const kRelationStateNone;
FOUNDATION_EXPORT NSString * const kRelationStateFriend;
FOUNDATION_EXPORT NSString * const kRelationStateBlocked;
FOUNDATION_EXPORT NSString * const kRelationStateGroupFriend;
FOUNDATION_EXPORT NSString * const kRelationStateKept;


@interface Contact : HXOModel <HXOClientProtocol>

@property (nonatomic, strong)   NSString        * type;
@property (nonatomic, strong)   NSData          * avatar;
@property (nonatomic, strong)   NSString        * avatarURL;
@property (nonatomic, strong)   NSString        * avatarUploadURL;
@property (nonatomic, strong)   NSString        * clientId;
@property (nonatomic, strong)   NSDate          *  latestMessageTime;
@property (nonatomic, strong)   NSDate          * presenceLastUpdated;
@property (nonatomic, strong)   NSString        * nickName;
@property (nonatomic, strong)   NSString        * status;

@property (nonatomic, retain)   GroupMembership * myGroupMembership;

@property (nonatomic, strong)   NSArray         * unreadMessages;
@property (nonatomic, strong)   NSArray         * latestMessage;

@property (nonatomic, strong)   NSData          * publicKey; // public key of this contact
@property (nonatomic, strong)   NSData          * verifiedKey; // verified public key of this contact
@property (nonatomic, strong)   NSString        * publicKeyId; // id of public key
@property (nonatomic, strong)   NSString        * connectionStatus;

@property (nonatomic, retain)   NSString        * relationshipState;
@property (nonatomic, retain)   NSDate          * relationshipLastChanged;
@property (nonatomic, readonly) BOOL              isBlocked;
@property (nonatomic, readonly) BOOL              isFriend;
@property (nonatomic, readonly) BOOL              isOnline;

@property (nonatomic, retain)   NSDate          * lastUpdateReceived;


@property (nonatomic ,strong)   NSNumber        * relationshipLastChangedMillis;
@property (nonatomic, strong)   NSNumber        * presenceLastUpdatedMillis;

@property (nonatomic, strong)   NSIndexPath     * rememberedLastVisibleChatCell;

@property (nonatomic,strong)    NSString        * publicKeyString; // b64-string


@property (nonatomic, strong)   NSMutableSet    * messages;
@property (nonatomic, strong)   NSMutableSet    * groupMemberships;
@property (readonly)            NSString        * nickNameWithStatus;

@property (nonatomic)           NSString        * groupMembershipList;

@property (nonatomic, strong)   UIImage         * avatarImage;

@property BOOL friendMessageShown;

- (SecKeyRef) getPublicKeyRef;

@end
