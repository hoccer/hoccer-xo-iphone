//
//  AudioAttachmentDataSource.h
//  HoccerXO
//
//  Created by Guido Lorenz on 02.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;
@class Contact;
@protocol AudioAttachmentDataSourceDelegate;

@interface AudioAttachmentDataSource : NSObject <UITableViewDataSource, NSFetchedResultsControllerDelegate>

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact managedObjectModel:(NSManagedObjectModel *)managedObjectModel;

- (id) initWithContact:(Contact *)contact;
- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, readonly) NSArray *attachments;
@property (nonatomic, weak) id<AudioAttachmentDataSourceDelegate> delegate;

@end
