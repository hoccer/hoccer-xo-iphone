//
//  DatasheetViewController.m
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetViewController.h"

#import "DatasheetTextInputCell.h"
#import "DatasheetKeyValueCell.h"
#import "DatasheetActionCell.h"
#import "DatasheetFooterTextView.h"
#import "HXOHyperLabel.h"

extern const CGFloat kHXOGridSpacing;

@interface DatasheetViewController ()

@property (nonatomic,readonly) UIImageView * backgroundImageView;

@end

@implementation DatasheetViewController

@synthesize backgroundImageView = _backgroundImageView;

- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [DatasheetTextInputCell class]];
    [self registerCellClass: [DatasheetKeyValueCell class]];
    [self registerCellClass: [DatasheetActionCell class]];

    [self registerHeaderFooterViewClass: [DatasheetFooterTextView class]];

    self.dataSheetController.delegate = self;

    // TableView changes its behaviour when writing to tableHEaderView :-/
    if (self.dataSheetController.tableHeaderView) {
        self.tableView.tableHeaderView = self.dataSheetController.tableHeaderView;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void) viewDidUnload {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) configureCell: (DatasheetCell*) cell withItem: (DatasheetItem*) item forRowAtIndexPath: (NSIndexPath*) indexPath {
    cell.titleLabel.text = item.title;
    cell.delegate = self;
    if ([cell respondsToSelector: @selector(valueView)]) {
        id valueView = [(id)cell valueView];
        [valueView setText: item.currentValue];
        if ([valueView respondsToSelector:@selector(setPlaceholder:)]) {
            [valueView setPlaceholder: item.placeholder];
        }
        if ([valueView respondsToSelector:@selector(setEnabled:)]) {
            [valueView setEnabled: item.isEnabled];
        }
    }
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    for (id key in self.prototypes) {
        id cell = self.prototypes[key];
        if ([cell respondsToSelector: @selector(preferredContentSizeChanged:)]) {
            [cell preferredContentSizeChanged: notification];
        }
    }
    [self.tableView reloadData];
}

#pragma mark - Table View Delegate & Data Source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSheetController.currentItems.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.dataSheetController.currentItems[section] items] count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    DatasheetCell * cell = [self.tableView dequeueReusableCellWithIdentifier: item.cellIdentifier];
    [self configureCell: cell withItem: item forRowAtIndexPath: indexPath];
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    DatasheetCell * prototype = (DatasheetCell*)[self prototypeCellForIdentifier: item.cellIdentifier];
    [self configureCell: prototype withItem: item forRowAtIndexPath: indexPath];
    return [prototype.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
}

- (void) tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector: @selector(setDelegate:)]) {
        [(id)cell setDelegate: nil];
    }
}

#pragma mark - Section Headers and Footers

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return FLT_MIN;
    }
    // TODO: ...
    return 3 * kHXOGridSpacing;
}

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0 && ! self.tableView.tableHeaderView) {
        return nil;
    }
    return nil;
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)sectionIndex {
    DatasheetSection * section = [self.dataSheetController itemForIndexPath: [NSIndexPath indexPathWithIndex: sectionIndex]];
    if (section.footerViewIdentifier) {
        id footer = self.headerFooterPrototypes[section.footerViewIdentifier];
        [self configureFooter: footer forSection: section];
        CGFloat height = [footer systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
        return height;
    }
    return 0;
}

- (UIView*) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)sectionIndex {
    DatasheetSection * section = [self.dataSheetController itemForIndexPath: [NSIndexPath indexPathWithIndex: sectionIndex]];
    if (section.footerViewIdentifier) {
        UIView * footerView = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier: section.footerViewIdentifier];
        [self configureFooter: footerView forSection: section];
        return footerView;
    }
    return nil;
}

- (void) configureFooter: (id) footer forSection: (DatasheetSection*) section {
    if ([footer respondsToSelector: @selector(label)]) {
        [[footer label] setAttributedText:  section.footerText];
    }
}


#pragma mark - Navigation Buttons

- (void) updateNavigationButtons {
    UIBarButtonItem * rightButton = nil;
    UIBarButtonItem * leftButton = nil;
    if (self.dataSheetController.isEditable) {
        if (self.dataSheetController.isEditing) {
            rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action:@selector(rightButtonPressed:)];
            rightButton.enabled = [self.dataSheetController allItemsValid];

            leftButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(leftButtonPressed:)];
        } else {
            rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemEdit target: self action:@selector(rightButtonPressed:)];
        }
    }
    self.navigationItem.rightBarButtonItem = rightButton;
    self.navigationItem.leftBarButtonItem = leftButton;
}

- (void) rightButtonPressed: (id) sender {
    [self.dataSheetController editModeChanged: sender];
    [self updateNavigationButtons];
}

- (void) leftButtonPressed: (id) sender {
    [self.dataSheetController cancelEditing: sender];
    //[self.dataSheetController editModeChanged: sender];
    [self updateNavigationButtons];
}

#pragma mark - Datasheet Controller Delegate

- (void) controllerDidChangeObject:(DatasheetController *)controller {
    [self updateNavigationButtons];
}

- (void) controllerWillChangeContent: (DatasheetController*) controller {
    [self.tableView beginUpdates];
}

- (void) controller: (DatasheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath {
    switch(type) {
        case DatasheetChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeUpdate:
            [self configureCell: (DatasheetCell*)[self.tableView cellForRowAtIndexPath:indexPath] withItem: [controller itemForIndexPath: indexPath] forRowAtIndexPath: indexPath];
            break;
        default:
            break;
    }
}

- (void) controller: (DatasheetController*) controller didChangeSection: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type {
    switch(type) {
        case DatasheetChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex: indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex: indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }

}

- (void) controllerDidChangeContent: (DatasheetController*) controller {
    [self.tableView endUpdates];
}

- (void) controller:(DatasheetController *)controller didChangeBackgroundImage:(UIImage *)image {
    self.backgroundImageView.image = image;
}

#pragma mark - Datasheet Cell Delegate

- (void) valueDidChange:(DatasheetCell *)cell valueView:(id)valueView {
    NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
    DatasheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    item.currentValue = [valueView text];
    self.navigationItem.rightBarButtonItem.enabled = [self.dataSheetController allItemsValid];
}

#pragma mark - Accessors

- (id) inspectedObject {
    return self.dataSheetController.inspectedObject;
}

- (void) setInspectedObject: (id) inspectedObject {
    self.dataSheetController.inspectedObject = inspectedObject;
}

#pragma mark - Background Image Handling

- (UIImageView*) backgroundImageView {
    if (! _backgroundImageView) {
        _backgroundImageView = [[UIImageView alloc] initWithFrame: self.tableView.tableHeaderView.bounds];
        _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        _backgroundImageView.layer.masksToBounds = YES;
        _backgroundImageView.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
        [self.tableView addSubview:_backgroundImageView];
        [self.tableView sendSubviewToBack: _backgroundImageView];
    }
    return _backgroundImageView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    CGFloat y =  scrollView.contentOffset.y + self.navigationController.navigationBar.frame.size.height + MIN(statusBarSize.width, statusBarSize.height);
    if (y  < 0) {
        CGSize restingSize = self.tableView.tableHeaderView.bounds.size;
        self.backgroundImageView.frame = CGRectMake(0, y, restingSize.width - y, restingSize.height - y);
        self.backgroundImageView.center = CGPointMake(self.view.center.x, self.backgroundImageView.center.y);
    }
}


@end
