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
#import "AttachmentInfo.h"
#import "AudioAttachmentCell.h"
#import "AudioAttachmentDataSourceDelegate.h"
#import "Contact.h"
#import "ContactCell.h"

@interface AudioAttachmentDataSource ()

@property (nonatomic, strong) NSArray *filteredAttachments;
@property (nonatomic, strong) NSArray *filteredContacts;

@end

@implementation AudioAttachmentDataSource

#pragma mark - Core Data Stack

- (NSManagedObjectContext *)mainObjectContext {
    return [[AppDelegate instance] mainObjectContext];
}

- (NSManagedObjectModel *)managedObjectModel {
    return [[AppDelegate instance] managedObjectModel];
}

#pragma mark - Fetched Results Controller

- (NSFetchRequest *) fetchRequest {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
}

- (NSFetchedResultsController *) fetchedResultsController {
    if (_fetchedResultsController == nil) {
        NSFetchRequest *fetchRequest = [self fetchRequest];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.mainObjectContext sectionNameKeyPath:nil cacheName:nil];
        _fetchedResultsController.delegate = self;
        [_fetchedResultsController performFetch:nil];
    }
    
    return _fetchedResultsController;
}

#pragma mark - Search

- (void) setSearchText:(NSString *)searchText {
    _searchText = searchText;
    
    if (searchText) {
        NSPredicate *attachmentSearchPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            Attachment *attachment = evaluatedObject;
            AttachmentInfo *info = [AttachmentInfo infoForAttachment:attachment];
            return [info.audioTitle rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
        }];

        NSArray *attachments = [self attachments];
        self.filteredAttachments = [attachments filteredArrayUsingPredicate:attachmentSearchPredicate];

        NSPredicate *contactSearchPredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            Contact *contact = evaluatedObject;
            return [contact.nickNameOrAlias rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound;
        }];

        NSArray *contacts = [attachments valueForKeyPath:@"@distinctUnionOfObjects.message.contact"];
        self.filteredContacts = [contacts filteredArrayUsingPredicate:contactSearchPredicate];
    } else {
        self.filteredAttachments = nil;
        self.filteredContacts = nil;
    }
}

#pragma mark - Sections

- (BOOL) hasContactSection {
    return [self.filteredContacts count] > 0;
}

- (BOOL) isContactSection:(NSInteger)section {
    return [self hasContactSection] && section == 0;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    if ([self hasContactSection]) {
        return 2;
    } else {
        return 1;
    }
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self isContactSection:section]) {
        return NSLocalizedString(@"audio_attachment_list_search_section_senders", nil);
    } else if ([self hasContactSection] && [self tableView:tableView numberOfRowsInSection:section] > 0) {
        return NSLocalizedString(@"audio_attachment_list_search_section_attachments", nil);
    } else {
        return nil;
    }
}

#pragma mark - Rows and Cells

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isContactSection:section]) {
        return [self.filteredContacts count];
    } else {
        if (self.filteredAttachments) {
            return [self.filteredAttachments count];
        } else {
            id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[0];
            return [sectionInfo numberOfObjects];
        }
    }
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isContactSection:indexPath.section]) {
        ContactCell *cell = [tableView dequeueReusableCellWithIdentifier:[ContactCell reuseIdentifier] forIndexPath:indexPath];
        [self configureContactCell:cell atIndexPath:indexPath];
        return cell;
    } else {
        AudioAttachmentCell *cell = [tableView dequeueReusableCellWithIdentifier:[AudioAttachmentCell reuseIdentifier] forIndexPath:indexPath];
        [self configureAudioAttachmentCell:cell atIndexPath:indexPath];
        return cell;
    }
}

- (void) configureAudioAttachmentCell:(AudioAttachmentCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Attachment *attachment = [self attachmentAtIndexPath:indexPath];
    cell.attachment = attachment;
    [cell highlightText:self.searchText];
}

- (void) configureContactCell:(ContactCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Contact *contact = [self contactAtIndexPath:indexPath];
    [ContactCell configureCell:cell forContact:contact];
    [cell highlightText:self.searchText];
}

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert(![self isContactSection:indexPath.section], @"indexPath not in attachment section");

    if (self.filteredAttachments) {
        return [self.filteredAttachments objectAtIndex:indexPath.row];
    } else {
        return [self specializedAttachmentAtIndexPath:indexPath];
    };
}

- (Attachment *) specializedAttachmentAtIndexPath:(NSIndexPath *)indexPath {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
}

- (Contact *) contactAtIndexPath:(NSIndexPath *)indexPath {
    NSAssert([self isContactSection:indexPath.section], @"indexPath not in sender section");

    return [self.filteredContacts objectAtIndex:indexPath.row];
}

- (NSIndexPath *) indexPathForAttachment:(Attachment *)attachment {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
}

#pragma mark - Fetched Results Controller Delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.delegate dataSourceWillChangeContent:self];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    [self.delegate dataSource:self didChangeAttachmentAtIndexPath:indexPath forChangeType:type newIndexPath:newIndexPath];
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

#pragma mark - NSCopying

- (id) copyWithZone:(NSZone *)zone {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"AudioAttachmentDataSource must be subclassed" userInfo:nil];
}

@end
