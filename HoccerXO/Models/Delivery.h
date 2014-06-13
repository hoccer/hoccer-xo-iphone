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
FOUNDATION_EXPORT NSString * const kDeliveryStateDelivered;
FOUNDATION_EXPORT NSString * const kDeliveryStateConfirmed;
FOUNDATION_EXPORT NSString * const kDeliveryStateFailed;

FOUNDATION_EXPORT NSString * const kDeliveryStateNew;
FOUNDATION_EXPORT NSString * const kDeliveryStateDelivering;
FOUNDATION_EXPORT NSString * const kDeliveryStateDelivered;
FOUNDATION_EXPORT NSString * const kDeliveryStateDeliveredAcknowledged;
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

-(BOOL)hasFailed;
-(BOOL)attachmentDownloadable;

-(BOOL)isInFinalState;
-(BOOL)isDelivered;
-(BOOL)isFailure;
-(BOOL)isAttachmentReceived;
-(BOOL)isMissingAttachment;

+(BOOL)isDeliveredState:(NSString*) state;
+(BOOL)isFailureState:(NSString*) state;
+(BOOL)isAcknowledgedState:(NSString*) state;
+(BOOL)shouldAcknowledgeStateForOutgoing:(NSString*) state;

+(BOOL)isAttachmentReceivedState:(NSString*) attachmentState;
+(BOOL)isAcknowledgedAttachmentState:(NSString*) attachmentState;
+(BOOL)shouldAcknowledgeAttachmentStateForOutgoing:(NSString*) attachmentState;
+(BOOL)shouldAcknowledgeAttachmentStateForIncoming:(NSString*) attachmentState;

@end
