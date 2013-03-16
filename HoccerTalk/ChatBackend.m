//
//  ChatBackend.m
//  HoccerTalk
//
//  Created by David Siegel on 28.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatBackend.h"

#import "Contact.h"
#import "Message.h"
#import "Delivery.h"
#import "AppDelegate.h"
#import "NSString+UUID.h"
#import "NSManagedObject+RPCDictionary.h"

@implementation ChatBackend

@synthesize managedObjectContext = _managedObjectContext;

- (Message*) sendMessage:(NSString *) text toContact: (Contact*) contact {
    Message * message =  (Message*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext: self.managedObjectContext];
    message.body = text;
    message.timeStamp = [NSDate date];
    message.contact = contact;
    message.isOutgoing = @YES;
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    message.messageId = @"";
    message.messageTag = [NSString stringWithUUID];

    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName:@"Delivery" inManagedObjectContext: self.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;
    delivery.receiver = contact;

    NSLog(@"rpc message: %@", [message rpcDictionary]);
    NSLog(@"rpc delivery: %@", [delivery rpcDictionary]);

    return message;
}

- (NSDictionary*) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary {
    Message * message =  (Message*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext: self.managedObjectContext];
    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName:@"Delivery" inManagedObjectContext: self.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;

    // TODO: handle the actual message

    [delivery updateWithDictionary: deliveryDictionary];
    delivery.state = [Delivery stateDelivered];

    return [delivery rpcDictionary];
}

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    AppDelegate * appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _managedObjectContext = appDelegate.managedObjectContext;
    return _managedObjectContext;
}

@end
