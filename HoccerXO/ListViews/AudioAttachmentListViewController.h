//
//  AudioAttachmentListViewController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"

@class Collection;
@class Contact;

@interface AudioAttachmentListViewController : HXOTableViewController <NSFetchedResultsControllerDelegate>

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact collection:(Collection *)collection managedObjectModel:(NSManagedObjectModel *)managedObjectModel;

@property (nonatomic, strong) Collection *collection;
@property (nonatomic, strong) Contact *contact;

@end
