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

@implementation AudioAttachmentDataSource

#pragma mark - Core Data Stack

- (NSManagedObjectContext *)managedObjectContext {
    return [[AppDelegate instance] mainObjectContext];
}

- (NSManagedObjectModel *)managedObjectModel {
    return [[AppDelegate instance] managedObjectModel];
}

#pragma mark - Fetched Results Controller

- (NSFetchRequest *) fetchRequest {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController == nil) {
        NSFetchRequest *fetchRequest = [self fetchRequest];
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
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
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

#pragma mark - Editing

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.delegate dataSource:self commitEditingStyle:editingStyle forAttachment:[self attachmentAtIndexPath:indexPath]];
}

#pragma mark - Properties

- (NSArray *) attachments {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
}

@end
