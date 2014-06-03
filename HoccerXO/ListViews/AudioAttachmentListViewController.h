//
//  AudioAttachmentListViewController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"

@class Contact;

@interface AudioAttachmentListViewController : HXOTableViewController <NSFetchedResultsControllerDelegate>

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact managedObjectModel:(NSManagedObjectModel *)managedObjectModel;

@end
