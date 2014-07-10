//
//  HXOAudioAttachmentDataSourcePlaylist.m
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioAttachmentDataSourcePlaylist.h"

@interface HXOAudioAttachmentDataSourcePlaylist ()

@property (nonatomic, strong) AudioAttachmentDataSource *dataSource;

@end

@implementation HXOAudioAttachmentDataSourcePlaylist

#pragma mark - Lifecycle

- (id) initWithDataSource:(AudioAttachmentDataSource *)dataSource {
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

#pragma mark - AudioAttachmentDataSourceDelegate

- (void) dataSourceWillChangeContent:(AudioAttachmentDataSource *)dataSource {}
- (void) dataSourceDidChangeContent:(AudioAttachmentDataSource *)dataSource {}
- (void) dataSource:(AudioAttachmentDataSource *)dataSource commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forAttachment:(Attachment *)attachment {}

- (void) dataSource:(AudioAttachmentDataSource *)dataSource didChangeAttachmentAtIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    switch(type) {
        case NSFetchedResultsChangeInsert: {
            [self.delegate playlist:self didInsertAttachmentAtIndex:newIndexPath.row];
            break;
        }
            
        case NSFetchedResultsChangeDelete: {
            [self.delegate playlist:self didRemoveAttachmentAtIndex:indexPath.row];
            break;
        }
            
        case NSFetchedResultsChangeUpdate: {
            break;
        }
            
        case NSFetchedResultsChangeMove: {
            [self.delegate playlist:self didMoveAttachmentFromIndex:indexPath.row toIndex:newIndexPath.row];
            break;
        }
    }
}

@end
