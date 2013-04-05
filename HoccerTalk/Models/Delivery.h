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

@interface Delivery : HoccerTalkModel

@property (nonatomic, strong) NSString * state;
@property (nonatomic, strong) TalkMessage *message;

@property (nonatomic, strong) Contact* receiver;

+ (NSString*) stateNew;
+ (NSString*) stateDelivering;
+ (NSString*) stateDelivered;
+ (NSString*) stateFailed;

@end
