//
//  DummyChatBackend.m
//  HoccerTalk
//
//  Created by David Siegel on 28.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "DummyChatBackend.h"
#import "AppDelegate.h"
#import "Contact.h"
#import "Message.h"


@implementation DummyChatBackend

- (id) init {
    self = [super init];
    if (self != nil) {
        [self addDummies: 100];
        self.blubberMessages = @[@"blub", @"blah", @"fasel", @"flup flup", @"brizzel", @"brazzel", @"brubbel", @"fizzel"];
        [self blubber];

    }
    return self;
}

- (void) addDummies: (long) messageCount {
    AppDelegate * appDelegate = ((AppDelegate *)[[UIApplication sharedApplication] delegate]);

    NSArray * avatars  = @[ @"schlumpf_schlumpfine", @"schlumpf_papa" ];
    NSArray * nicks    = @[ @"Schlumpfine", @"Daddy S" ];
    NSArray * messages = @[ @[ @"Käffchen?"
                             , @"k, bin in 10min da..."
                             , @"bis gloich"
                             , @"Was geht heute abend?"
                             , @"bin schon verabredet. Aber wir könnten am WE einen trinken gehen. In der Panke ist irgendwie HipHop party... Backyard Joints. Lorem ipsum blah fasel blub..."
                             , @"Mein Router ist abgeraucht :-/. Kannst Du ein ordentliches DSL Modem empfehlen?"
                             , @"Ich würde mal bei den Fritzboxen von AVM gucken. Das ist echt ordentliche Hardware."
                             , @"Check mal deine mail..."
                             , @"kewl! Will ich haben."
                             ]
                          , @[ @"Hast Du deine Hausaufgaben gemacht?"
                             , @"Ja, Papa Schlumpf..."
                             , @"und wasch Dir vor dem essen die Hände"
                             , @"Ja, Papa Schlumpf..."
                             , @"und geh nicht wieder so spät ins Bett"
                             , @"Ja, Papa Schlumpf..."
                             , @"Sei Sonnatg bitte pünktlich. Wir essen zeitig."
                             , @"Ja, Papa Schlumpf..."
                             ]
                          ];



    NSManagedObjectContext *importContext = [[NSManagedObjectContext alloc] init];
    [importContext setPersistentStoreCoordinator: appDelegate.persistentStoreCoordinator];
    [importContext setUndoManager:nil];

    NSFetchRequest *contactRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * contactEntity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext: importContext];
    [contactRequest setEntity:contactEntity];

    NSError *error;
    unsigned long contactCount = [importContext countForFetchRequest: contactRequest error: &error];

    if (contactCount == 0) {
        NSLog(@"adding dummy messages");

        int contactIndex = 0;
        for (NSString* avatar in avatars) {

            Contact * contact =  (Contact*)[NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext: importContext];
            contact.nickName = [nicks objectAtIndex: contactIndex];
            contact.avatar = UIImagePNGRepresentation([UIImage imageNamed: avatar]);
            
            NSDate *date = [NSDate dateWithTimeIntervalSinceNow: - (60*60*24*30)];
            contact.lastMessageTime = date;
            
            for(int i = 0; i < messageCount; ++i) {
                Message * message =  (Message*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext: importContext];

                message.text = [[messages objectAtIndex: contactIndex] objectAtIndex: i % ((NSArray*)[messages objectAtIndex: contactIndex]).count];
                message.timeStamp = date;
                message.contact = contact;
                message.isOutgoing = i % 2 == 0 ? @NO : @YES;
                message.isRead = @NO;

                message.timeSection = [contact sectionTitleForMessageTime: date];
                contact.lastMessageTime = date;

                int interval = rand() % (int)(2.5 * 60);
                date = [NSDate dateWithTimeInterval: interval sinceDate: date];
            }
            contactIndex += 1;
        }
        [importContext save:&error];
        if (error != nil) {
            NSLog(@"ERROR - failed to save message: %@", error);
            abort();
        }
    }

}


- (void) blubber {
    [self receiveRandomMessage];
    [NSTimer scheduledTimerWithTimeInterval: rand() % 300
                                     target:self
                                   selector:@selector(blubber)
                                   userInfo:nil
                                    repeats:NO];
}

- (void) receiveRandomMessage {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext: self.managedObjectContext];
    [fetchRequest setEntity:entity];

    NSError *error = nil;
    NSArray *contacts = [self.managedObjectContext executeFetchRequest: fetchRequest error:&error];
    if (contacts == nil)
    {
        NSLog(@"Error: %@", error);
        abort();
    }

    Message * message =  (Message*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext: self.managedObjectContext];
    Contact * contact = [contacts objectAtIndex: rand() % contacts.count];
    message.text = [self.blubberMessages objectAtIndex: rand() % self.blubberMessages.count];
    message.timeStamp = [NSDate date];
    message.contact = contact;
    message.isOutgoing = @NO;
    message.timeSection = [contact sectionTitleForMessageTime: message.timeStamp];
    contact.lastMessageTime = message.timeStamp;

    // TODO: find a better way to do this...
    [message.contact willChangeValueForKey: @"unreadMessages"];
    message.isRead = @NO;
    [self.managedObjectContext refreshObject: contact mergeChanges:YES];
    [message.contact didChangeValueForKey: @"unreadMessages"];
}

@end
