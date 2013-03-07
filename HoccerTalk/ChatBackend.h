//
//  ChatBackend.h
//  HoccerTalk
//
//  Created by David Siegel on 28.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Contact;

@interface ChatBackend : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (void) sendMessage: (NSString*) text toContact: (Contact*) contact;

@end
