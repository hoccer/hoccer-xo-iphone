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


@interface Delivery : HXOModel

@property (nonatomic, strong) NSString * state;
@property (nonatomic, strong) HXOMessage *message;
@property (nonatomic, strong) NSDate * timeChanged;
@property (nonatomic, strong) NSString * keyId;

@property (nonatomic, strong) Contact* receiver;
@property (nonatomic, strong) Contact* sender;
@property (nonatomic, strong) Group * group;
@property (nonatomic, strong) NSData* keyCiphertext; // encrypted message crypto key

@property (nonatomic) NSString* keyCiphertextString; // encrypted message crypto key as b64-string

@property (nonatomic) NSData* keyCleartext;
@property (nonatomic) NSData* keyCleartextEC;
@property (nonatomic) NSData* keyCleartextRSA;

@property (nonatomic) NSString* receiverKeyId;

@property (nonatomic) NSNumber * timeChangedMillis;


@end
