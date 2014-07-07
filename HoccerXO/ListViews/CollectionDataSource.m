//
//  ConversationDataSource.m
//  HoccerXO
//
//  Created by Guido Lorenz on 03.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CollectionDataSource.h"

#import "Collection.h"
#import "CollectionItem.h"

@interface CollectionDataSource ()

@property (nonatomic, strong) Collection *collection;

@end

@implementation CollectionDataSource

#pragma mark - Initialization

- (id) initWithCollection:(Collection *)collection {
    self = [super init];
    
    if (self) {
        self.collection = collection;
    }
    
    return self;
}

#pragma mark - Fetch Request

- (NSFetchRequest *) fetchRequest {
    NSDictionary *vars = @{ @"collection" : self.collection };
    
    NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"CollectionItemsForCollection" substitutionVariables:vars];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return fetchRequest;
}

#pragma mark - Data Accessors

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath {
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSAssert([object isKindOfClass:[CollectionItem class]], @"Expected CollectionItem");
    CollectionItem* collectionItem = (CollectionItem *)object;
    return collectionItem.attachment;
}

- (NSArray *) attachments {
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES];
    NSArray *items = [self.collection.items sortedArrayUsingDescriptors:@[ sortDescriptor ]];
    NSMutableArray *attachments = [NSMutableArray arrayWithCapacity:[items count]];

    for (CollectionItem *item in items) {
        [attachments addObject:item.attachment];
    }
    
    return attachments;
}

#pragma mark - Editing

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    [self.collection moveAttachmentAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
}

@end
