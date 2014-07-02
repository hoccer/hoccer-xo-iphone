//
//  AudioAttachmentListDataSource.m
//  HoccerXO
//
//  Created by Guido Lorenz on 02.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentDataSource.h"

#import "AppDelegate.h"
#import "Attachment.h"
#import "AudioAttachmentCell.h"
#import "AudioAttachmentDataSourceDelegate.h"
#import "Collection.h"
#import "Contact.h"

@interface AudioAttachmentDataSource ()

@property (nonatomic, strong) Collection *collection;
@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;

@end

@implementation AudioAttachmentDataSource

#pragma mark - Initialization

- (id) initWithContact:(Contact *)contact collection:(Collection *)collection {
    self = [super init];
    
    if (self) {
        self.contact = contact;
        self.collection = collection;
    }
    
    return self;
}

#pragma mark - Core Data Stack

- (NSManagedObjectContext *)managedObjectContext {
    return [[AppDelegate instance] managedObjectContext];
}

- (NSManagedObjectModel *)managedObjectModel {
    return [[AppDelegate instance] managedObjectModel];
}

#pragma mark - Fetched Results Controller

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact collection:(Collection *)collection managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    NSDictionary *vars = @{ @"contact" : contact ? contact : [NSNull null],
                            @"collection" : collection ? collection : [NSNull null] };
    
    NSFetchRequest *fetchRequest = [managedObjectModel fetchRequestFromTemplateWithName:@"ReceivedAudioAttachments" substitutionVariables:vars];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"message.timeReceived" ascending: NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return fetchRequest;
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController == nil) {
        NSFetchRequest *fetchRequest = [self.class fetchRequestForContact:self.contact collection:self.collection managedObjectModel:self.managedObjectModel];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
        _fetchedResultsController.delegate = self;
        [_fetchedResultsController performFetch:nil];
    }
    
    return _fetchedResultsController;
}

#pragma mark - Rows and Cells

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AudioAttachmentCell *cell = [tableView dequeueReusableCellWithIdentifier:[AudioAttachmentCell reuseIdentifier] forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void) configureCell:(AudioAttachmentCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Attachment *attachment = [self attachmentAtIndexPath:indexPath];
    cell.attachment = attachment;
}

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath {
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if ([object isKindOfClass:[Attachment class]]) {
        return (Attachment *)object;
    }
    
    return nil;
}

#pragma mark - Editing

- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Attachment *attachment = [self attachmentAtIndexPath:indexPath];
        [[AppDelegate instance] deleteObject:attachment.message];
        [[AppDelegate instance] saveDatabase];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.collection != nil;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    [self.collection moveAttachmentAtIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];
    [[AppDelegate instance] saveDatabase];
}

#pragma mark - Fetched Results Controller Delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.delegate dataSourceWillChangeContent:self];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    [self.delegate dataSource:self didChangeAttachment:[self attachmentAtIndexPath:indexPath] atIndexPath:indexPath forChangeType:type newIndexPath:newIndexPath];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.delegate dataSourceDidChangeContent:self];
}

#pragma mark - Properties

- (NSArray *) attachments {
    // The fetchedObjects array seems to change, so we take an immutable copy
    return [[self.fetchedResultsController fetchedObjects] copy];
}

@end
