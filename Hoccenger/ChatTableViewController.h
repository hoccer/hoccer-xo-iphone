//
//  ChatTableViewController.h
//  Hoccenger
//
//  Created by David Siegel on 13.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"

@interface ChatTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>
{
    NSMutableDictionary        *resultsControllers;
}

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (void) setPartner: (Contact*) partner;

@end
