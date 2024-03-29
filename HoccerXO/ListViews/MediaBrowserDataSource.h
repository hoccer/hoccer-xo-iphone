//
//  MediaBrowserDataSource.h
//  HoccerXO
//
//  Created by Guido Lorenz on 03.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MediaAttachmentDataSource.h"

@class Contact;

@interface MediaBrowserDataSource : MediaAttachmentDataSource

//+ (NSFetchRequest *)fetchRequestWithManagedObjectModel:(NSManagedObjectModel *)managedObjectModel;
//+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact managedObjectModel:(NSManagedObjectModel *)managedObjectModel;
+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact withMediaTypes:(NSArray*)mediaTypes managedObjectModel:(NSManagedObjectModel *)managedObjectModel;

- (id) initWithContact:(Contact *)contact andMediaTypes:(NSArray*)mediaTypes;
- (void)selectMediaTypes:(NSArray*)mediaTypes;

@end
