//
//  DataSheetViewController.m
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DataSheetViewController.h"

#import "DataSheetTextInputCell.h"
#import "DataSheetKeyValueCell.h"
#import "DataSheetActionCell.h"

extern const CGFloat kHXOGridSpacing;

@interface DataSheetViewController ()

@end

@implementation DataSheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [DataSheetTextInputCell class]];
    [self registerCellClass: [DataSheetKeyValueCell class]];
    [self registerCellClass: [DataSheetActionCell class]];

    self.dataSheetController.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSheetController.items.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.dataSheetController.items[section] items] count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DataSheetItem * item = [self.dataSheetController.items[indexPath.section] items][indexPath.row];
    DataSheetCell * cell = [self.tableView dequeueReusableCellWithIdentifier: item.cellIdentifier];
    [self configureCell: cell withItem: item forRowAtIndexPath: indexPath];
    return cell;
}

- (void) configureCell: (DataSheetCell*) cell withItem: (DataSheetItem*) item forRowAtIndexPath: (NSIndexPath*) indexPath {
    cell.titleLabel.text = item.title;
    if ([cell respondsToSelector: @selector(valueView)]) {
        [[(id)cell valueView] setText: [self.dataSheetController valueForItem: item]];
        if ([[(id)cell valueView] respondsToSelector:@selector(setPlaceholder:)]) {
            [[(id)cell valueView] setPlaceholder: item.placeholder];
        }
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    DataSheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    DataSheetCell * prototype = (DataSheetCell*)[self prototypeCellForIdentifier: item.cellIdentifier];
    [self configureCell: prototype withItem: item forRowAtIndexPath: indexPath];
    return [prototype.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
}

- (void) controllerWillChangeContent: (DataSheetController*) controller {
    [self.tableView beginUpdates];
}

- (void) controller: (DataSheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DataSheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath {

}

- (void) controller: (DataSheetController*) controller didChangeSection: (NSUInteger) sectionIndex {

}

- (void) controllerDidChangeContent: (DataSheetController*) controller {
    [self.tableView endUpdates];
}


@end
