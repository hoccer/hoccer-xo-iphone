//
//  MusicBrowserDataSource.m
//  HoccerXO
//
//  Created by Guido Lorenz on 03.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MusicBrowserDataSource.h"

#import "Attachment.h"
#import "Contact.h"
#import "AppDelegate.h"

@interface MusicBrowserDataSource ()

@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) NSArray *mediaTypes;

@end

@implementation MusicBrowserDataSource

#pragma mark - Initialization

- (id) initWithContact:(Contact *)contact andMediaTypes:(NSArray*)mediaTypes{
    self = [super init];
    
    if (self) {
        self.contact = contact;
        self.mediaTypes = mediaTypes;
    }
    
    return self;
}

- (void)selectMediaTypes:(NSArray*)mediaTypes {
    self.mediaTypes = mediaTypes;
}


#pragma mark - Fetch Request
/*
+ (NSFetchRequest *)fetchRequestWithManagedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    return [MusicBrowserDataSource fetchRequestForContact:nil managedObjectModel:managedObjectModel];
}
*/

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact withMediaTypes:(NSArray*)mediaTypes managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
#ifdef orig
    NSDictionary *vars = @{ @"contact" : contact ? contact : [NSNull null] };
    
    NSFetchRequest *fetchRequest = [managedObjectModel fetchRequestFromTemplateWithName:@"AudioAttachments" substitutionVariables:vars];
#else
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: [Attachment entityName] inManagedObjectContext: AppDelegate.instance.mainObjectContext];
    [fetchRequest setEntity:entity];
    //[fetchRequest setSortDescriptors: self.sortDescriptors];
    
    NSMutableArray *predicateArray = [NSMutableArray array];
    
    // general predicate
    [predicateArray addObject: [NSPredicate predicateWithFormat:@"message == nil OR (message.isOutgoingFlag == 0 AND contentSize == transferSize) OR (message.isOutgoingFlag == 1 AND assetURL != nil)"]];
    

    // contact predicate
    if (contact != nil) {
        [predicateArray addObject: [NSPredicate predicateWithFormat:@"message.contact == %@", contact]];
    } else {
        [predicateArray addObject: [NSPredicate predicateWithFormat:@"duplicate == 'ORIGINAL'"]];        
    }
    if (mediaTypes != nil) {
        [self addPredicates: predicateArray forMediaTypes:mediaTypes];
    }
    //[self addPredicates: predicateArray forMediaTypes:@[@"audio"]];
    //if(searchString.length) {
    //    [self addSearchPredicates: predicateArray searchString: searchString];
    //}
    NSPredicate * filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicateArray];
    [fetchRequest setPredicate:filterPredicate];
#endif
    //NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"message.timeAccepted" ascending: NO]];
    NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"fileModificationDate" ascending: NO]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return fetchRequest;
}

- (NSFetchRequest *) fetchRequest {
    //if (self.contact) {
    return [MusicBrowserDataSource fetchRequestForContact:self.contact withMediaTypes:self.mediaTypes managedObjectModel:self.managedObjectModel];
    //} else {
    //    return [MusicBrowserDataSource fetchRequestWithManagedObjectModel:self.managedObjectModel];
    //}
}
/*
+ (void) addPredicates: (NSMutableArray*) predicates forContact:(Contact *)contact {
    //NSDictionary *vars = @{ @"contact" : contact ? contact : [NSNull null] };
    
    //[predicates addObject: [NSPredicate predicateWithFormat:@"mediaType == 'audio'"]];
    [predicates addObject: [NSPredicate predicateWithFormat:@"mediaType == 'audio' AND (message == nil OR (message.isOutgoingFlag == 0 AND contentSize == transferSize) OR (message.isOutgoingFlag == 1 AND assetURL != nil)) AND playable == 'YES' AND (%K == nil OR message.contact == %K) AND (NOT humanReadableFileName BEGINSWITH 'recording')", contact, contact]];
}
*/
+ (void) addPredicates: (NSMutableArray*) predicates forMediaTypes:(NSArray *)mediaTypes {
    NSMutableArray *predicateArray = [NSMutableArray array];
    for (NSString * mediaType in mediaTypes) {
        if ([mediaType isEqualToString:@"audio"]) {
            [predicateArray addObject: [NSPredicate predicateWithFormat:@"mediaType == %@ AND playable == 'YES'", mediaType]];
        } else {
            [predicateArray addObject: [NSPredicate predicateWithFormat:@"mediaType == %@", mediaType]];
        }
    }
    NSPredicate * filterPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicateArray];
    [predicates addObject:filterPredicate];
}

#pragma mark - Sections

- (BOOL) hasContactSection {
    return [super hasContactSection] && self.contact == nil;
}

#pragma mark - Data Accessors

- (Attachment *) specializedAttachmentAtIndexPath:(NSIndexPath *)indexPath {
    id attachment = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSAssert(attachment == nil || [attachment isKindOfClass:[Attachment class]], @"Expected Attachment or nil");
    return attachment;
}

- (NSIndexPath *) indexPathForAttachment:(Attachment *)attachment {
    return [self.fetchedResultsController indexPathForObject:attachment];
}

- (NSArray *) attachments {
    // The fetchedObjects array seems to change, so we take an immutable copy
    return [[self.fetchedResultsController fetchedObjects] copy];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [[MusicBrowserDataSource alloc] initWithContact:self.contact andMediaTypes:self.mediaTypes];
}

@end
