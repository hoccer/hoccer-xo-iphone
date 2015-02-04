//
//  AudioAttachmentDataSource.h
//  HoccerXO
//
//  Created by Guido Lorenz on 02.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MediaAttachmentDataSourceDelegate.h"

@class Attachment;
@class Contact;

@interface MediaAttachmentDataSource : NSObject <UITableViewDataSource, NSFetchedResultsControllerDelegate, NSCopying>

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath;
- (Contact *) contactAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *) indexPathForAttachment:(Attachment *)attachment;

- (NSFetchRequest *) fetchRequest;

- (BOOL) hasContactSection;
- (BOOL) isContactSection:(NSInteger)section;

@property (nonatomic, readonly) NSArray *attachments;
@property (nonatomic, weak) id<MediaAttachmentDataSourceDelegate> delegate;

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readonly) NSManagedObjectContext *mainObjectContext;
@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;

@property (nonatomic, strong) NSString *searchText;

@end
