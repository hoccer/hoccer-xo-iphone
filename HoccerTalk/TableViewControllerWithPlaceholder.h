//
//  TableViewControllerWithPlaceholder.h
//  HoccerTalk
//
//  Created by David Siegel on 14.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "EmptyTablePlaceholderCell.h"

@interface TableViewControllerWithPlaceholder : UITableViewController

@property (nonatomic,strong) EmptyTablePlaceholderCell * emptyTablePlaceholder;

- (BOOL) isEmpty;
- (void) updateEmptyTablePlaceholderAnimated: (BOOL) animated;

@end
