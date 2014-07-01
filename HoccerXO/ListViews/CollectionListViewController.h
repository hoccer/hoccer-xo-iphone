//
//  CollectionListViewController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 25.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"

@class Collection;

@interface CollectionListViewController : HXOTableViewController <NSFetchedResultsControllerDelegate, UIAlertViewDelegate>

- (UITableViewCellAccessoryType) cellAccessoryType;
- (Collection *) collectionAtIndexPath:(NSIndexPath *)indexPath;

@end
