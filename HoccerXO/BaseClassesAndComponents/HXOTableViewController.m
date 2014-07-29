//
//  UserDefaultsControllerViewController.m
//  HoccerXO
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"

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

- (id) initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle: style];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    _prototypes = [NSMutableDictionary dictionary];
    _headerFooterPrototypes = [NSMutableDictionary dictionary];
}

- (UITableViewCell*) prototypeCellOfClass:(id)cellClass {
    return _prototypes[[cellClass reuseIdentifier]];
}

- (UITableViewCell*) prototypeCellForIdentifier: (NSString*) identifier {
    return _prototypes[identifier];
}

- (UITableViewCell*) dequeueReusableCellOfClass:(id)cellClass forIndexPath: (NSIndexPath*) indexPath {
    return [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier] forIndexPath: indexPath];
}

- (void) registerCellClass: (id) cellClass {
    if (_prototypes[[cellClass reuseIdentifier]] == nil) {
        [self.tableView registerClass: cellClass forCellReuseIdentifier: [cellClass reuseIdentifier]];
        _prototypes[[cellClass reuseIdentifier]] = [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier]];
    }
}

- (void) registerHeaderFooterViewClass: (id) class {
    if (_headerFooterPrototypes[[class reuseIdentifier]] == nil) {
        [self.tableView registerClass: class forHeaderFooterViewReuseIdentifier: [class reuseIdentifier]];
        _headerFooterPrototypes[[class reuseIdentifier]] = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier: [class reuseIdentifier]];
    }
}
@end
