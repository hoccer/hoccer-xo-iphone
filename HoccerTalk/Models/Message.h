//
//  Message.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Contact;
@class Attachment;
@class Delivery;

@interface Message : NSManagedObject

@property (nonatomic, retain) NSString* body;
@property (nonatomic, retain) NSDate*   timeStamp;
@property (nonatomic, retain) NSNumber* isOutgoing;
@property (nonatomic, retain) NSString* timeSection;
@property (nonatomic, retain) NSNumber* isRead;
@property (nonatomic, retain) NSString* messageId;
@property (nonatomic, retain) NSString* messageTag;

@property (nonatomic, retain) Contact*  contact;
@property (nonatomic, retain) Attachment * attachment;
@property (nonatomic, retain) NSMutableSet * deliveries;

@end
