//
//  Delivery.h
//  HoccerXO
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "HXOModel.h"

@class HXOMessage;
@class Contact;
@class Group;

FOUNDATION_EXPORT NSString * const kDeliveryStateNew;
FOUNDATION_EXPORT NSString * const kDeliveryStateDelivering;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredPrivate;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredPrivateAcknowledged;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredUnseen;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredUnseenAcknowledged;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredSeen;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredSeenAcknowledged;
FOUNDATION_EXPORT NSString * const kDeliveryStateFailed;
FOUNDATION_EXPORT NSString * const kDeliveryStateRejected;
FOUNDATION_EXPORT NSString * const kDeliveryStateAborted;
FOUNDATION_EXPORT NSString * const kDeliveryStateAbortedAcknowledged;
FOUNDATION_EXPORT NSString * const kDeliveryStateFailedAcknowledged;
FOUNDATION_EXPORT NSString * const kDeliveryStateRejectedAcknowledged;

FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_NONE;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_NEW;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOADING;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_PAUSED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOADED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_RECEIVED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_RECEIVED_ACKNOWLEDGED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED_ACKNOWLEDGED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED_ACKNOWLEDGED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED_ACKNOWLEDGED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED;
FOUNDATION_EXPORT NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED_ACKNOWLEDGED;

@interface Delivery : HXOModel

@property (nonatomic, strong) NSString * state;
@property (nonatomic, strong) HXOMessage *message;
@property (nonatomic, strong) NSDate * timeChanged;
@property (nonatomic, strong) NSString * keyId;
@property (nonatomic, strong) NSString * attachmentState;

@property (nonatomic, strong) Contact* receiver;
@property (nonatomic, strong) Contact* sender;
@property (nonatomic, strong) Group * group;
@property (nonatomic, strong) NSData* keyCiphertext; // encrypted message crypto key

@property (nonatomic) NSString* keyCiphertextString; // encrypted message crypto key as b64-string

@property (nonatomic) NSData* keyCleartext;

@property (nonatomic) NSString* receiverKeyId;

@property (nonatomic) NSNumber * timeChangedMillis;

-(BOOL)isGroupDelivery;

-(BOOL)attachmentDownloadable;
-(BOOL)attachmentUploadable;

-(BOOL)isStateFailed;
-(BOOL)isStateDelivering;
-(BOOL)isStateNew;
-(BOOL)isPending;
-(BOOL)isFailure;
-(BOOL)isDelivered;
-(BOOL)isInFinalState;

-(BOOL)isSeen;
-(BOOL)isUnseen;
-(BOOL)isPrivate;

-(BOOL)isAttachmentReceived;
-(BOOL)isAttachmentFailure;
-(BOOL)isAttachmentPending;

-(BOOL)isMissingAttachment;

+(BOOL)isDeliveredState:(NSString*) state;
+(BOOL)isFailureState:(NSString*) state;
+(BOOL)isAcknowledgedState:(NSString*) state;

+(BOOL)isSeenState:(NSString*)state;
+(BOOL)isUnseenState:(NSString*)state;
+(BOOL)isPrivateState:(NSString*)state;

+(BOOL)shouldAcknowledgeStateForOutgoing:(NSString*) state;

+(BOOL)isAttachmentReceivedState:(NSString*) attachmentState;
+(BOOL)isAcknowledgedAttachmentState:(NSString*) attachmentState;
+(BOOL)isAttachmentFailureState:(NSString*) attachmentState;

+(BOOL)shouldAcknowledgeAttachmentStateForOutgoing:(NSString*) attachmentState;
+(BOOL)shouldAcknowledgeAttachmentStateForIncoming:(NSString*) attachmentState;

@end
