//
//  AudioAttachmentListViewController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"
#import "AddToCollectionListViewControllerDelegate.h"

@class Collection;
@class Contact;

@interface AudioAttachmentListViewController : HXOTableViewController <NSFetchedResultsControllerDelegate, AddToCollectionListViewControllerDelegate>

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact collection:(Collection *)collection managedObjectModel:(NSManagedObjectModel *)managedObjectModel;

@property (nonatomic, strong) Collection *collection;
@property (nonatomic, strong) Contact *contact;

@property (nonatomic, strong) UIButton *addToCollectionButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *sendButton;

@end
