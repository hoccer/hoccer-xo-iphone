//
//  Delivery.h
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Message;
@class Contact;

@interface Delivery : NSManagedObject

@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) Message *message;

@property (nonatomic, retain) Contact* receiver;

+ (NSString*) stateNew;
+ (NSString*) stateDelivering;
+ (NSString*) stateDelivered;
+ (NSString*) stateFailed;

@end
