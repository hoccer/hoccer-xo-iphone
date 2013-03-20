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
@synthesize managedObjectModel = _managedObjectModel;

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

    contact.latestMessageTime = message.timeStamp;

    [self.managedObjectContext refreshObject: contact mergeChanges: YES];

    return message;
}

- (NSDictionary*) receiveMessage: (NSDictionary*) messageDictionary withDelivery: (NSDictionary*) deliveryDictionary {
    Message * message =  (Message*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext: self.managedObjectContext];
    Delivery * delivery =  (Delivery*)[NSEntityDescription insertNewObjectForEntityForName:@"Delivery" inManagedObjectContext: self.managedObjectContext];
    [message.deliveries addObject: delivery];
    delivery.message = message;

    NSDictionary * vars = @{ @"clientId" : deliveryDictionary[@"receiverId"]};
    NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"ContactByClientId" substitutionVariables: vars];
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (array == nil)
    {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    Contact * contact = array[0];

    [delivery updateWithDictionary: deliveryDictionary];
    delivery.state = [Delivery stateDelivered];

    // TODO: handle the actual message
    message.isOutgoing = NO;
    message.isRead = NO;
    message.timeStamp = [NSDate date]; // TODO: use actual timestamp
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    message.contact = contact;
    [contact.messages addObject: message];
    [message updateWithDictionary: messageDictionary];

    contact.latestMessageTime = message.timeStamp;

    [self.managedObjectContext refreshObject: contact mergeChanges: YES];

    return [delivery rpcDictionary];
}

- (NSManagedObjectContext*) managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    AppDelegate * appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _managedObjectContext = appDelegate.managedObjectContext;
    return _managedObjectContext;
}

- (NSManagedObjectModel*) managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    AppDelegate * appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _managedObjectModel = appDelegate.managedObjectModel;
    return _managedObjectModel;
}

@end
