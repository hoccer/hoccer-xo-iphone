//
//  ChatTableViewController.h
//  Hoccenger
//
//  Created by David Siegel on 13.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"

@class MessageCell;

@interface ChatTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
    NSMutableDictionary        *resultsControllers;
}

@property (strong) MessageCell* messageCell;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;

- (void) setPartner: (Contact*) partner;
- (void) scrollToBottom;

@end
