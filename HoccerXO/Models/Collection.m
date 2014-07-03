//
//  Collection.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "Collection.h"

#import "Attachment.h"
#import "CollectionItem.h"

@implementation Collection

@dynamic items;
@dynamic name;

- (void) appendAttachments:(NSArray *)attachments {
    for (Attachment *attachment in attachments) {
        CollectionItem *collectionItem = [NSEntityDescription insertNewObjectForEntityForName:@"CollectionItem" inManagedObjectContext:self.managedObjectContext];
        collectionItem.attachment = attachment;
        collectionItem.collection = self;
        collectionItem.index = [self.items count];
    }
}

- (void) moveAttachmentAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {
    NSMutableOrderedSet *mutableAttachments = [self mutableOrderedSetValueForKey:@"attachments"];
    NSIndexSet *sourceIndexSet = [NSIndexSet indexSetWithIndex:sourceIndex];
    [mutableAttachments moveObjectsAtIndexes:sourceIndexSet toIndex:destinationIndex];
}

@end
