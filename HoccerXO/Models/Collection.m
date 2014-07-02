//
//  Collection.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "Collection.h"

@implementation Collection

@dynamic attachments;
@dynamic name;

- (void) appendAttachments:(NSArray *)attachments {
    // Work around a bug in the generated accessors for ordered relationships
    // http://stackoverflow.com/questions/7385439/exception-thrown-in-nsorderedset-generated-accessors

    NSMutableOrderedSet *mutableAttachments = [self mutableOrderedSetValueForKey:@"attachments"];
    [mutableAttachments addObjectsFromArray:attachments];
}

- (void) moveAttachmentAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex {
    NSMutableOrderedSet *mutableAttachments = [self mutableOrderedSetValueForKey:@"attachments"];
    NSIndexSet *sourceIndexSet = [NSIndexSet indexSetWithIndex:sourceIndex];
    [mutableAttachments moveObjectsAtIndexes:sourceIndexSet toIndex:destinationIndex];
}

@end
