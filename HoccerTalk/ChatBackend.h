//
//  ChatBackend.h
//  HoccerTalk
//
//  Created by David Siegel on 28.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Contact;
@class Message;

@interface ChatBackend : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;

- (Message*) sendMessage: (NSString*) text toContact: (Contact*) contact;
- (NSDictionary*) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary;

@end
