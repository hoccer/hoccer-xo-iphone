//
//  Delivery.h
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "HoccerTalkModel.h"

@class TalkMessage;
@class Contact;

FOUNDATION_EXPORT NSString * const kDeliveryStateNew;
FOUNDATION_EXPORT NSString * const kDeliveryStateDelivering;
FOUNDATION_EXPORT NSString * const kDeliveryStateDelivered;
FOUNDATION_EXPORT NSString * const kDeliveryStateConfirmed;
FOUNDATION_EXPORT NSString * const kDeliveryStateFailed;


@interface Delivery : HoccerTalkModel

@property (nonatomic, strong) NSString * state;
@property (nonatomic, strong) TalkMessage *message;
@property (nonatomic, strong) NSDate * timeChanged;

@property (nonatomic, strong) Contact* receiver;
@property (nonatomic, strong) NSData* keyCiphertext; // encrypted message crypto key

@property (nonatomic) NSString* keyCiphertextString; // encrypted message crypto key as b64-string

@property (nonatomic) NSData* keyCleartext;

@property (nonatomic) NSString* receiverKeyId;

@end
