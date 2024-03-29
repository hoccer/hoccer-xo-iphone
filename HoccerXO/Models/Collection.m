//
//  Collection.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "Collection.h"

#import "CollectionItem.h"

@implementation Collection

@dynamic items;
@dynamic name;

- (void) appendAttachments:(NSArray *)attachments {
    NSSet *attachmentsInCollection = [self.items valueForKeyPath:@"@distinctUnionOfObjects.attachment"];
    NSMutableSet *newAttachments = [NSMutableSet setWithArray:attachments];
    [newAttachments minusSet:attachmentsInCollection];

    for (Attachment *attachment in newAttachments) {
        CollectionItem *collectionItem = [NSEntityDescription insertNewObjectForEntityForName:@"CollectionItem" inManagedObjectContext:self.managedObjectContext];
        collectionItem.index = (int)[self.items count];
        collectionItem.attachment = attachment;
        collectionItem.collection = self;
    }
}

- (void) moveAttachmentAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {
    if (sourceIndex == destinationIndex) {
        return;
    }
    
    for (CollectionItem *item in self.items) {
        if (sourceIndex < destinationIndex) {
            // item is moved downwards
            if (item.index < sourceIndex) {
                // item is above the moved item
                // => stays in place
            } else if (item.index == sourceIndex) {
                // item is moved item
                // => move to destination
                item.index = (int)destinationIndex;
            } else if (item.index <= destinationIndex) {
                // item is between moved item and destination
                // => move up by one
                item.index -= 1;
            } else {
                // item is below the destination
                // => stays in place
            }
        } else {
            // item is moved upwards
            if (item.index > sourceIndex) {
                // item is below the moved item
                // => stays in place
            } else if (item.index == sourceIndex) {
                // item is moved item
                // => move to destination
                item.index = (int)destinationIndex;
            } else if (item.index >= destinationIndex) {
                // item is between moved item and destination
                // => move down by one
                item.index += 1;
            } else {
                // item is above the destination
                // => stays in place
            }
        }
    }
}

- (void) removeAttachment:(Attachment *)attachment {
    for (CollectionItem *item in self.items) {
        if (item.attachment == attachment) {
            [self removeItemAtIndex:item.index];
        }
    }
}

- (void) removeItemAtIndex:(NSUInteger)itemIndex {
    for (CollectionItem *item in self.items) {
        if (item.index == itemIndex) {
            [self.managedObjectContext deleteObject:item];
        } else if (item.index > itemIndex) {
            item.index -= 1;
        }
    }
}

@end
