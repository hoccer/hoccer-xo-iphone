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

    self.dataSheetController.inspectedObject = @{@"nickname": @"Dingenshier"};

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSheetController.currentItems.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.dataSheetController.currentItems[section] items] count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DataSheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
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

- (void) controllerDidChangeObject:(DataSheetController *)controller {
    [self updateRightButton];
}

- (void) updateRightButton {
    UIBarButtonItem * button = nil;
    if (self.dataSheetController.isEditable) {
        button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: (self.dataSheetController.isEditing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit) target: self        action:@selector(rightButtonPressed:)];
    }
    self.navigationItem.rightBarButtonItem = button;

}

- (void) rightButtonPressed: (id) sender {
    [self.dataSheetController editModeChanged: sender];
    [self updateRightButton];
}

- (void) controllerWillChangeContent: (DataSheetController*) controller {
    [self.tableView beginUpdates];
}

- (void) controller: (DataSheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DataSheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath {
    switch(type) {
        case DataSheetChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DataSheetChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DataSheetChangeUpdate:
            /* workaround - see:
             * http://stackoverflow.com/questions/14354315/simultaneous-move-and-update-of-uitableviewcell-and-nsfetchedresultscontroller
             * and
             * http://developer.apple.com/library/ios/#releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/
             */
            [self configureCell: (DataSheetCell*)[self.tableView cellForRowAtIndexPath:indexPath] withItem: [controller itemForIndexPath: indexPath] forRowAtIndexPath: indexPath];
            break;
        default:
            break;
    }
}

- (void) controller: (DataSheetController*) controller didChangeSection: (NSUInteger) sectionIndex forChangeType: (DataSheetChangeType) type {
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }

}

- (void) controllerDidChangeContent: (DataSheetController*) controller {
    [self.tableView endUpdates];
}


@end
