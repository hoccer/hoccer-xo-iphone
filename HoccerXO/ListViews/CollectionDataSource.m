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

- (id) initWithCollection:(Collection *)collection {
    self = [super init];
    
    if (self) {
        self.collection = collection;
    }
    
    return self;
}

- (NSFetchRequest *) fetchRequest {
    NSDictionary *vars = @{ @"collection" : self.collection };
    
    NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"CollectionItemsForCollection" substitutionVariables:vars];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return fetchRequest;
}

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath {
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSAssert([object isKindOfClass:[CollectionItem class]], @"Expected CollectionItem");
    CollectionItem* collectionItem = (CollectionItem *)object;
    return collectionItem.attachment;
}

@end
