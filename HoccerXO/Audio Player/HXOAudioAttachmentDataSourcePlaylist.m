//
//  HXOAudioAttachmentDataSourcePlaylist.m
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioAttachmentDataSourcePlaylist.h"

@interface HXOAudioAttachmentDataSourcePlaylist ()

@property (nonatomic, strong) MediaAttachmentDataSource *dataSource;

@end

@implementation HXOAudioAttachmentDataSourcePlaylist

#pragma mark - Lifecycle

- (id) initWithDataSource:(MediaAttachmentDataSource *)dataSource {
    self = [super init];
    
    if (self) {
        self.dataSource = [dataSource copy];
        self.dataSource.delegate = self;
    }
    
    return self;
}

#pragma mark - Playlist Protocol

- (NSUInteger) count {
    return [self.dataSource tableView:nil numberOfRowsInSection:0];
}

- (Attachment *) attachmentAtIndex:(NSUInteger)index {
    return [self.dataSource attachmentAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
}

- (NSUInteger) indexOfAttachment:(Attachment *)attachment {
    return [[self.dataSource indexPathForAttachment:attachment] row];
}

#pragma mark - AudioAttachmentDataSourceDelegate

- (void) dataSourceWillChangeContent:(MediaAttachmentDataSource *)dataSource {}
- (void) dataSourceDidChangeContent:(MediaAttachmentDataSource *)dataSource {}
- (void) dataSource:(MediaAttachmentDataSource *)dataSource commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forAttachment:(Attachment *)attachment {}

- (void) dataSource:(MediaAttachmentDataSource *)dataSource didChangeAttachmentAtIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.delegate playlistDidChange:self];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.delegate playlist:self didRemoveAttachmentAtIndex:indexPath.row];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self.delegate playlistDidChange:self];
            break;
            
        case NSFetchedResultsChangeMove:
            [self.delegate playlistDidChange:self];
            break;
    }
}

@end
