//
//  AudioAttachmentDataSource.h
//  HoccerXO
//
//  Created by Guido Lorenz on 02.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;
@protocol AudioAttachmentDataSourceDelegate;

@interface AudioAttachmentDataSource : NSObject <UITableViewDataSource, NSFetchedResultsControllerDelegate>

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath;
- (NSFetchRequest *) fetchRequest;

@property (nonatomic, readonly) NSArray *attachments;
@property (nonatomic, weak) id<AudioAttachmentDataSourceDelegate> delegate;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;

@end
