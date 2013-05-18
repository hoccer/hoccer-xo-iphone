//
//  GroupViewController.h
//  HoccerXO
//
//  Created by David Siegel on 17.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOGroupedTableViewController.h"

@class HXOBackend;
@class Group;

@interface GroupViewController : HXOGroupedTableViewController

@property (nonatomic,strong) Group * group;
@property (nonatomic,readonly) HXOBackend * backend;

@end
