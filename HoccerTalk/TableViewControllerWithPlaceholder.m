//
//  TableViewControllerWithPlaceholder.m
//  HoccerTalk
//
//  Created by David Siegel on 14.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TableViewControllerWithPlaceholder.h"

@interface TableViewControllerWithPlaceholder ()

@end

@implementation TableViewControllerWithPlaceholder

- (void) viewDidLoad {
    [super viewDidLoad];
    UINib * nib = [UINib nibWithNibName: @"EmptyTablePlaceholderCell" bundle: [NSBundle mainBundle]];
    [self.tableView registerNib: nib forCellReuseIdentifier: [EmptyTablePlaceholderCell reuseIdentifier]];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    [self.tableView beginUpdates];
    [self updateEmptyTablePlaceholder];
    [self.tableView endUpdates];
}

- (void) updateEmptyTablePlaceholder {
    if ([self isEmpty] && self.emptyTablePlaceholder == nil) {
        NSIndexPath * indexPath = [NSIndexPath indexPathForItem: 0 inSection: 0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        self.emptyTablePlaceholder = [self.tableView dequeueReusableCellWithIdentifier: [EmptyTablePlaceholderCell reuseIdentifier]];
    } else if ( ! [self isEmpty] && self.emptyTablePlaceholder != nil) {
        NSIndexPath * indexPath = [NSIndexPath indexPathForItem: 0 inSection: 0];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        self.emptyTablePlaceholder = nil;
    }
}

- (BOOL) isEmpty {
    return NO;
}

@end
