//
//  UserDefaultsControllerViewController.h
//  HoccerXO
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HXOTableViewController : UITableViewController
{
    NSMutableDictionary * _prototypes;
}

- (void) registerCellClass: (id) cellClass;
- (UITableViewCell*) prototypeCellOfClass: (id) cellClass;
- (UITableViewCell*) prototypeCellForIdentifier: (NSString*) identifier;
- (UITableViewCell*) dequeueReusableCellOfClass: (id) cellClass forIndexPath: (NSIndexPath*) indexPath;

@end
