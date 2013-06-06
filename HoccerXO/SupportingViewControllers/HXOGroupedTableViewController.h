//
//  UserDefaultsControllerViewController.h
//  HoccerXO
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HXOGroupedTableViewController : UITableViewController
{
    NSMutableDictionary * _prototypes;
    //NSArray *             _items;
}

- (UITableViewCell*) prototypeCellOfClass: (id) cellClass;
- (UITableViewCell*) dequeueReusableCellOfClass: (id) cellClass forIndexPath: (NSIndexPath*) indexPath;
//- (NSArray*) populateItems;

@end
