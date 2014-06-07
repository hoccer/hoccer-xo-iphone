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
FOUNDATION_EXPORT NSString * const kRelationStateInvited;
FOUNDATION_EXPORT NSString * const kRelationStateInvitedMe;
FOUNDATION_EXPORT NSString * const kRelationStateGroupFriend;
FOUNDATION_EXPORT NSString * const kRelationStateKept;


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
@property (nonatomic, strong)   NSString        * isNearbyTag; // using string as boolean because booleans totally suck in CoreData predicates;
                                                               // values are the string "YES" for true, all other values indicate false

@property (nonatomic, retain)   GroupMembership * myGroupMembership;

@property (nonatomic, strong)   NSArray         * unreadMessages;
@property (nonatomic, strong)   NSArray         * latestMessage;

@property (nonatomic, strong)   NSData          * publicKey; // public key of this contact
@property (nonatomic, strong)   NSData          * verifiedKey; // verified public key of this contact
@property (nonatomic, strong)   NSString        * publicKeyId; // id of public key
@property (nonatomic, strong)   NSString        * connectionStatus;

@property (nonatomic, retain)   NSString        * relationshipState;
@property (nonatomic, retain)   NSDate          * relationshipLastChanged;

// dynamic key properties
@property (nonatomic,strong)    NSString        * publicKeyString; // b64-string
@property (readonly)            NSNumber        * keyLength;       // length of public key in bits


// class type helper
@property (nonatomic, readonly) BOOL              isGroup;


// relationsShip helpers
@property (nonatomic, readonly) BOOL              isBlocked;
@property (nonatomic, readonly) BOOL              isInvited;
@property (nonatomic, readonly) BOOL              invitedMe;
@property (nonatomic, readonly) BOOL              isFriend;
@property (nonatomic, readonly) BOOL              isGroupFriend;
@property (nonatomic, readonly) BOOL              isKept;         // valid for both single contacts and groups
@property (nonatomic, readonly) BOOL              isKeptRelation; // only valid for non-group contacts
@property (nonatomic, readonly) BOOL              isKeptGroup;    // only valid for groups
@property (nonatomic, readonly) BOOL              isNotRelated;

// presence state helpers
@property (nonatomic, readonly) BOOL              isOffline;
@property (nonatomic, readonly) BOOL              isBackground;
@property (nonatomic, readonly) BOOL              isOnline;
@property (nonatomic, readonly) BOOL              isTyping;
@property (nonatomic, readonly) BOOL              isPresent;
@property (nonatomic, readonly) BOOL              isConnected;

@property (nonatomic, readonly) BOOL              isNearby; // valid for both single contacts and groups
@property (nonatomic, readonly) BOOL              isNearbyContact; // only valid for non-group contacts

@property (nonatomic, retain)   NSDate          * lastUpdateReceived;

@property (nonatomic ,strong)   NSNumber        * relationshipLastChangedMillis;
@property (nonatomic, strong)   NSNumber        * presenceLastUpdatedMillis;

@property (nonatomic, strong)   NSIndexPath     * rememberedLastVisibleChatCell;

@property (nonatomic, strong)   NSMutableSet    * messages;
@property (nonatomic, strong)   NSMutableSet    * deliveriesSent;
@property (nonatomic, strong)   NSMutableSet    * deliveriesReceived;
@property (nonatomic, strong)   NSMutableSet    * groupMemberships;
@property (readonly)            NSString        * nickNameWithStatus;

@property (nonatomic)           NSString        * groupMembershipList;

@property (nonatomic, strong)   UIImage         * avatarImage;

@property BOOL friendMessageShown;

- (SecKeyRef) getPublicKeyRef;
- (BOOL) hasPublicKey;
- (void) updateNearbyFlag;



@end
