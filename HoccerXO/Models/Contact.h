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
@class Attachment;

FOUNDATION_EXPORT NSString * const kRelationStateNone;
FOUNDATION_EXPORT NSString * const kRelationStateFriend;
FOUNDATION_EXPORT NSString * const kRelationStateBlocked;
FOUNDATION_EXPORT NSString * const kRelationStateInvited;
FOUNDATION_EXPORT NSString * const kRelationStateInvitedMe;
FOUNDATION_EXPORT NSString * const kRelationStateGroupFriend;
FOUNDATION_EXPORT NSString * const kRelationStateInternalKept;

FOUNDATION_EXPORT NSString * const kPresenceStateOnline;
FOUNDATION_EXPORT NSString * const kPresenceStateOffline;
FOUNDATION_EXPORT NSString * const kPresenceStateBackground;
FOUNDATION_EXPORT NSString * const kPresenceStateTyping;


@interface Contact : HXOModel <HXOClientProtocol>

@property (nonatomic, strong)   NSString        * type;
@property (nonatomic, strong)   NSData          * avatar;
@property (nonatomic, strong)   NSString        * avatarURL;
@property (nonatomic, strong)   NSString        * avatarUploadURL;
@property (nonatomic, strong)   NSString        * clientId;
@property (nonatomic, strong)   NSDate          * latestMessageTime;
@property (nonatomic, strong)   NSDate          * presenceLastUpdated;
@property (nonatomic, strong)   NSString        * nickName;
@property (nonatomic, strong)   NSString        * alias;
@property (nonatomic, strong)   NSString        * status;

@property (nonatomic, retain)   GroupMembership * myGroupMembership;

@property (nonatomic, strong)   NSArray         * unreadMessages;
@property (nonatomic, strong)   NSArray         * latestMessage;

@property (nonatomic, strong)   NSData          * publicKey; // public key of this contact
@property (nonatomic, strong)   NSData          * verifiedKey; // verified public key of this contact
@property (nonatomic, strong)   NSString        * publicKeyId; // id of public key
@property (nonatomic, strong)   NSString        * connectionStatus;

@property (nonatomic, retain)   NSString        * relationshipState;
@property (nonatomic, retain)   NSString        * relationshipUnblockState;
@property (nonatomic, retain)   NSDate          * relationshipLastChanged;

@property (nonatomic, retain)   NSString        * notificationPreference;

@property (nonatomic, retain)   NSString        * savedMessageBody;
@property (nonatomic, retain)   NSDictionary    * savedAttachments;
@property (nonatomic, retain)   Attachment      * savedAttachment;

// dynamic key properties
@property (nonatomic,strong)    NSString        * publicKeyString; // b64-string
@property (readonly)            NSNumber        * keyLength;       // length of public key in bits


// class type helper
@property (nonatomic, readonly) BOOL              isGroup;


// relationsShip helpers
@property (nonatomic, readonly) BOOL              isBlocked;
@property (nonatomic, readonly) BOOL              isInvited;
@property (nonatomic, readonly) BOOL              invitedMe;
@property (nonatomic, readonly) BOOL              isInvitable;
@property (nonatomic, readonly) BOOL              isFriend;
@property (nonatomic, readonly) BOOL              isGroupFriend;
@property (nonatomic, readonly) BOOL              isKept;         // valid for both single contacts and groups
@property (nonatomic, readonly) BOOL              isKeptRelation; // only valid for non-group contacts
@property (nonatomic, readonly) BOOL              isKeptGroup;    // only valid for groups
@property (nonatomic, readonly) BOOL              isNotRelated;
@property (nonatomic, readonly) BOOL              isDirectlyRelated;

// presence state helpers
@property (nonatomic, readonly) BOOL              isOffline;
@property (nonatomic, readonly) BOOL              isBackground;
@property (nonatomic, readonly) BOOL              isOnline;
@property (nonatomic, readonly) BOOL              isTyping;
@property (nonatomic, readonly) BOOL              isPresent;
@property (nonatomic, readonly) BOOL              isConnected;

@property (nonatomic, readonly) BOOL              isNearby; // valid for both single contacts and groups
@property (nonatomic, readonly) BOOL              isNearbyContact; // only valid for non-group contacts

@property (nonatomic, readonly) BOOL              isWorldwide; // valid for both single contacts and groups
@property (nonatomic, readonly) BOOL              isWorldwideContact; // only valid for non-group contacts
@property (nonatomic, readonly) BOOL              isSuspendedWorldwideContact; // only valid for non-group contacts

@property (nonatomic, retain)   NSDate          * lastUpdateReceived;

@property (nonatomic ,strong)   NSNumber        * relationshipLastChangedMillis;
@property (nonatomic, strong)   NSNumber        * presenceLastUpdatedMillis;

@property (nonatomic, strong)   NSIndexPath     * rememberedLastVisibleChatCell;

@property (nonatomic, strong)   NSMutableSet    * messages;
@property (nonatomic, strong)   NSMutableSet    * deliveriesSent;
@property (nonatomic, strong)   NSMutableSet    * deliveriesReceived;
@property (nonatomic, strong)   NSMutableSet    * groupMemberships;
@property (readonly)            NSString        * nickNameWithStatus;
@property (readonly)            NSString        * nickNameOrAlias;

@property (nonatomic)           NSString        * groupMembershipList;

@property (nonatomic, strong)   UIImage         * avatarImage;

@property                       BOOL              deletedObject;

- (SecKeyRef) getPublicKeyRef;
- (BOOL) hasPublicKey;
- (BOOL)hasNotificationsEnabled;



@end
