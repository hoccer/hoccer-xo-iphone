//
//  AudioAttachmentDataSourceDelegate.h
//  HoccerXO
//
//  Created by Guido Lorenz on 02.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;
@class AudioAttachmentDataSource;

@protocol AudioAttachmentDataSourceDelegate <NSObject>

- (void) dataSourceWillChangeContent:(AudioAttachmentDataSource *)dataSource;
- (void) dataSourceDidChangeContent:(AudioAttachmentDataSource *)dataSource;

- (void) dataSource:(AudioAttachmentDataSource *)dataSource didChangeAttachment:(Attachment *)attachment atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath;

@end
