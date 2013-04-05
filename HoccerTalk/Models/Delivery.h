//
//  Delivery.h
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class TalkMessage;
@class Contact;

@interface Delivery : NSManagedObject

@property (nonatomic, strong) NSString * state;
@property (nonatomic, strong) TalkMessage *message;

@property (nonatomic, strong) Contact* receiver;

+ (NSString*) stateNew;
+ (NSString*) stateDelivering;
+ (NSString*) stateDelivered;
+ (NSString*) stateFailed;

@end
