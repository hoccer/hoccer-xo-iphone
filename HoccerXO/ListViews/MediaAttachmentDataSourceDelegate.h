//
//  MediaAttachmentDataSourceDelegate.h
//  HoccerXO
//
//  Created by Guido Lorenz on 02.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;
@class MediaAttachmentDataSource;

@protocol MediaAttachmentDataSourceDelegate <NSObject>

- (void) dataSourceWillChangeContent:(MediaAttachmentDataSource *)dataSource;
- (void) dataSourceDidChangeContent:(MediaAttachmentDataSource *)dataSource;

- (void) dataSource:(MediaAttachmentDataSource *)dataSource didChangeAttachmentAtIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath;

- (void) dataSource:(MediaAttachmentDataSource *)dataSource commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forAttachment:(Attachment *)attachment;

@end
