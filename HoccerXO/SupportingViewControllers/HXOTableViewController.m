//
//  UserDefaultsControllerViewController.m
//  HoccerXO
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"
#import "UserDefaultsCells.h"

@interface HXOTableViewController ()

@end

@implementation HXOTableViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    _prototypes = [[NSMutableDictionary alloc] init];
}

- (UITableViewCell*) prototypeCellOfClass:(id)cellClass {
    [self cacheClass: cellClass];
    return _prototypes[cellClass];
}

- (UITableViewCell*) dequeueReusableCellOfClass:(id)cellClass forIndexPath: (NSIndexPath*) indexPath {
    [self cacheClass: cellClass];
    return [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier] forIndexPath: indexPath];
}

- (void) cacheClass: (id) cellClass {
    if (_prototypes[cellClass] == nil) {
        [self.tableView registerClass: cellClass forCellReuseIdentifier: [cellClass reuseIdentifier]];
        _prototypes[cellClass] = [[cellClass alloc] initWithStyle: UITableViewStyleGrouped  reuseIdentifier: [cellClass reuseIdentifier]];
    }

}
@end
