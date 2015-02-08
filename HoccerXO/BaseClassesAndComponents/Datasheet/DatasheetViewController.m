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
#import "DatasheetSwitchCell.h"
#import "DatasheetHeaderFooterTextView.h"
#import "HXOHyperLabel.h"
#import "HXOUI.h"
#import "HXOUI.h" // needed for header height hack
#import "disclosure_arrow.h"
#import "VectorArtView.h"
#import "WebViewController.h"
#import "AppDelegate.h"
#import "HXOLocalization.h"

#define SEGUE_DEBUG         NO
#define INSPECTION_DEBUG    NO

static CGFloat kHeaderHeight;

@interface DatasheetViewController ()

@property (nonatomic,readonly) UIImageView            * backgroundImageView;
@property (nonatomic,readonly) UINavigationController * webViewController;

@end

@implementation DatasheetViewController

@synthesize backgroundImageView = _backgroundImageView;
@synthesize webViewController = _webViewController;

+ (void) initialize {
    if (self == [DatasheetViewController class]) {
        kHeaderHeight = 3 * kHXOGridSpacing;
    }
}


- (void) setDataSheetController:(DatasheetController *)dataSheetController {
    _dataSheetController = dataSheetController;
    dataSheetController.delegate = self;
    self.navigationItem.title = NSLocalizedString(dataSheetController.title, nil);
}


- (void) awakeFromNib {
    [super awakeFromNib];
    self.title = NSLocalizedString(self.dataSheetController.title, nil);
    self.tabBarItem.image = self.dataSheetController.tabBarIcon.image;
}


- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.tableView.style != UITableViewStyleGrouped) {
        NSLog(@"ERROR: %@ requires a grouped table view", NSStringFromClass([self class]));
    }

    [self registerCellClass: [DatasheetTextInputCell class]];
    [self registerCellClass: [DatasheetKeyValueCell class]];
    [self registerCellClass: [DatasheetActionCell class]];
    [self registerCellClass: [DatasheetSwitchCell class]];

    [self registerHeaderFooterViewClass: [DatasheetHeaderFooterTextView class]];

    self.tableView.allowsSelectionDuringEditing = YES;

    [self.dataSheetController registerCellClasses: self];

    // TableView changes its behaviour when writing to tableHeaderView :-/
    if (self.dataSheetController.tableHeaderView) {
        self.tableView.tableHeaderView = self.dataSheetController.tableHeaderView;
    }
    //self.dataSheetController.delegate = self;

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    if (self.dataSheetController.isEditing != self.isEditing) {
        [self setEditing: self.dataSheetController.isEditing animated: animated];
    }
}

- (void) viewDidDisappear:(BOOL)animated {
    if (SEGUE_DEBUG) NSLog(@"DataSheetViewController:viewDidDisappear");
    if ([self isMovingFromParentViewController]) {
        if (SEGUE_DEBUG) NSLog(@"isMovingFromParentViewController");
        [AppDelegate.instance endInspecting:self.dataSheetController.inspectedObject withInspector:self.dataSheetController];
        self.dataSheetController.inspectedObject = nil;
    }
    if ([self isBeingDismissed]) {
        if (SEGUE_DEBUG) NSLog(@"isBeingDismissed");
    }
    [super viewDidDisappear: animated];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction) unwindToSheetView: (UIStoryboardSegue*) unwindSegue {
}


- (void) configureCell: (DatasheetCell*) cell withItem: (DatasheetItem*) item forRowAtIndexPath: (NSIndexPath*) indexPath {

    NSString * title = NSLocalizedString(item.title, nil);
    if ([title isEqualToString:item.title]) {
        title = HXOLabelledLocalizedString(item.title,nil);
    }
    title = title;
    cell.titleLabel.text = title;

    if ([cell respondsToSelector: @selector(setDelegate:)]) {
        [cell setDelegate: self];
    }

    UIColor * titleColor = item.titleTextColor;
    if ( ! titleColor) {
        if ([cell.reuseIdentifier isEqualToString: @"DatasheetActionCell"]) {
            //titleColor = self.view.tintColor;
            titleColor = [UIColor blackColor];
        } else {
            titleColor = [HXOUI theme].lightTextColor;
        }
    }
    cell.titleLabel.textColor = titleColor;

    UIView * accessoryView = nil;
    switch (item.accessoryStyle) {
        case DatasheetAccessoryDisclosure:
            accessoryView = [[VectorArtView alloc] initWithVectorArt: [[disclosure_arrow alloc] init]];
            break;
        case DatasheetAccessoryNone:
            accessoryView = nil;
            break;
    }

    cell.hxoAccessoryView = accessoryView;
    cell.hxoAccessoryAlignment = HXOCellAccessoryAlignmentCenter;
    
    if ([cell respondsToSelector: @selector(valueView)]) {
        id valueView = [(id)cell valueView];
        if ([valueView respondsToSelector:@selector(setText:)]) {
            id currentValue = [item.currentValue isKindOfClass: [NSString class]] ? item.currentValue : [item.currentValue stringValue];
            if (item.valueFormatString) {
                currentValue = [NSString stringWithFormat: NSLocalizedString(item.valueFormatString, nil), currentValue];
            }
            [valueView setText: currentValue];
        }
        if ([valueView respondsToSelector:@selector(setOn:animated:)]) {
            BOOL v = [item.currentValue boolValue];
            if (v != [valueView isOn]) {
                [valueView setOn: v animated: YES];
            }
        }
        if ([valueView respondsToSelector:@selector(setPlaceholder:)]) {
            [valueView setPlaceholder: item.valuePlaceholder];
        }
        if ([valueView respondsToSelector:@selector(setEnabled:)]) {
            [valueView setEnabled: item.isEnabled];
        }
        if ([valueView respondsToSelector:@selector(setKeyboardType:)]) {
            [valueView setKeyboardType: item.keyboardType];
        }
        if ([valueView respondsToSelector:@selector(setReturnKeyType:)]) {
            [valueView setReturnKeyType: item.returnKeyType];
        }
        if ([valueView respondsToSelector:@selector(setAdjustsFontSizeToFitWidth:)]) {
            [valueView setAdjustsFontSizeToFitWidth: item.adjustFontSize];
        }
    }

    if ([cell respondsToSelector: @selector(busyIndicator)]) {
        UIActivityIndicatorView * busyIndicator = [(id)cell busyIndicator];
        if (busyIndicator.isAnimating != item.isBusy) {
            if (item.isBusy) {
                [busyIndicator startAnimating];
            } else {
                [busyIndicator stopAnimating];
            }
        }
    }

    [self.dataSheetController configureCell: cell withItem: item atIndexPath: indexPath];

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
    return [self.dataSheetController.currentItems[section] count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    DatasheetCell * cell = [self.tableView dequeueReusableCellWithIdentifier: item.cellIdentifier];
    [self configureCell: cell withItem: item forRowAtIndexPath: indexPath];
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    DatasheetCell * prototype = (DatasheetCell*)[self prototypeCellForIdentifier: item.cellIdentifier];
    [self configureCell: prototype withItem: item forRowAtIndexPath: indexPath];
    return ceilf([prototype.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height) + 1;
}

- (void) tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector: @selector(setDelegate:)]) {
        [(id)cell setDelegate: nil];
    }
    if ([cell respondsToSelector: @selector(busyIndicator)]) {
        [[(id)cell busyIndicator] stopAnimating];
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    if (item.isEnabled && item.target && [item.target respondsToSelector: item.action]) {
        IMP imp = [item.target methodForSelector: item.action];
        void (*func)(id, SEL, id) = (void *)imp;
        func(item.target, item.action, item);
    }
    if (item.segueIdentifier && ! [item.segueIdentifier isEqualToString:@""]) {
        [self performSegueWithIdentifier: item.segueIdentifier sender: self];
    }

    // Attempt to work around dissapearing separators
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: [self.tableView indexPathForSelectedRow]];
    [self.dataSheetController prepareForSegue: segue withItem: item sender: sender];
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    return item.isDeletable;
}

- (NSString*) tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    return item.deleteButtonTitle;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.dataSheetController editRemoveItem: item];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        [self.dataSheetController editInsertItem: item];
    }
}

#pragma mark - Table Section Headers and Footers

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)sectionIndex {
    CGFloat height = kHeaderHeight;
    DatasheetSection * section = [self.dataSheetController itemAtIndexPath: [NSIndexPath indexPathWithIndex: sectionIndex]];
    if (section.headerViewIdentifier) {
        id view = self.headerFooterPrototypes[section.headerViewIdentifier];
        [self configureHeaderFooter: view withText: section.title labelPadding: UIEdgeInsetsMake(kHXOGridSpacing, 0, kHXOGridSpacing, 0) font: [self headerFont] alignment: section.titleTextAlignment];
        height = [view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    } else if (sectionIndex == 0) {
        height = FLT_MIN;
    }
    return height;
}

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)sectionIndex {
    DatasheetSection * section = [self.dataSheetController itemAtIndexPath: [NSIndexPath indexPathWithIndex: sectionIndex]];
    UIView * view = nil;
    if (section.headerViewIdentifier) {
        view = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier: section.headerViewIdentifier];
        [self configureHeaderFooter: view withText: section.title labelPadding: UIEdgeInsetsMake(kHXOGridSpacing, 0, kHXOGridSpacing, 0) font: [self headerFont] alignment: section.titleTextAlignment];
    }
    return view;
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)sectionIndex {
    DatasheetSection * section = [self.dataSheetController itemAtIndexPath: [NSIndexPath indexPathWithIndex: sectionIndex]];
    CGFloat height = 0;
    if (section.footerViewIdentifier) {
        id view = self.headerFooterPrototypes[section.footerViewIdentifier];
        [self configureHeaderFooter: view withText: section.footerText labelPadding: UIEdgeInsetsMake( kHXOGridSpacing, 0, kHXOGridSpacing, 0) font: [self footerFont] alignment:NSTextAlignmentLeft];
        height = [view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    }
    return height;
}

- (UIView*) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)sectionIndex {
    DatasheetSection * section = [self.dataSheetController itemAtIndexPath: [NSIndexPath indexPathWithIndex: sectionIndex]];
    UIView * view = nil;
    if (section.footerViewIdentifier) {
        view = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier: section.footerViewIdentifier];

        [self configureHeaderFooter: view withText: section.footerText labelPadding: UIEdgeInsetsMake(kHXOGridSpacing, 0, kHXOGridSpacing, 0) font: [self footerFont] alignment:NSTextAlignmentLeft];
    }
    return view;
}

- (UIFont*) footerFont {
    return [HXOUI theme].smallTextFont;
}

- (UIFont*) headerFont {
    return [HXOUI theme].smallTextFont;
}

- (void) configureHeaderFooter: (id) view withText: (NSAttributedString*) text labelPadding: (UIEdgeInsets) padding font: (UIFont*) font alignment: (NSTextAlignment) alignment {
    if ([view respondsToSelector: @selector(label)]) {

        [[view label] setAttributedText:  text];

        if ([view respondsToSelector: @selector(setLabelPadding:)]) {
            [view setLabelPadding: padding];
        }

        if ([[view label] isKindOfClass: [HXOHyperLabel class]]) {
            HXOHyperLabel * label = [(id)view label];
            label.delegate = self;
            label.textAlignment = alignment;
            label.font = font;
            label.textColor = [HXOUI theme].smallBoldTextColor;
            //label.linkColor = [HXOUI theme].footerTextLinkColor;
        }
    }
}

- (void) tableView:(UITableView *)tableView didEndDisplayingHeaderView:(id) header forSection:(NSInteger)section {
    [self clearHeaderFooterDelegate: header];
}

- (void) tableView:(UITableView *)tableView didEndDisplayingFooterView:(id) footer forSection:(NSInteger)section {
    [self clearHeaderFooterDelegate: footer];
}

- (void) clearHeaderFooterDelegate: (id) view {
    if ([view respondsToSelector: @selector(label)] && [[view label] isKindOfClass: [HXOHyperLabel class]]) {
        [[view label] setDelegate: nil];
    }
}


- (void) hyperLabel: (HXOHyperLabel*) label didPressLink: (id) link long: (BOOL) longPress {
    ((WebViewController*)self.webViewController.viewControllers[0]).homeUrl = link;
    [self.navigationController presentViewController: self.webViewController animated: YES completion: nil];
}

- (UINavigationController*) webViewController {
    if ( ! _webViewController) {
        _webViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"webViewController"];
    }
    return _webViewController;
}

#pragma mark - Navigation Buttons

- (void) updateNavigationButtons {
    UIBarButtonItem * rightButton = nil;
    UIBarButtonItem * leftButton = nil;
    if (self.dataSheetController.isEditable) {
        if (self.dataSheetController.isEditing) {
            rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action:@selector(rightButtonPressed:)];
            rightButton.enabled = [self.dataSheetController allItemsValid];

            if (self.dataSheetController.isCancelable) {
                leftButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(leftButtonPressed:)];
            }
        } else {
            rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemEdit target: self action:@selector(rightButtonPressed:)];
        }
    }
    self.navigationItem.rightBarButtonItem = rightButton;
    self.navigationItem.leftBarButtonItem = leftButton;
}

- (void) rightButtonPressed: (id) sender {
    [self.dataSheetController editModeChanged: sender];
    [self setEditing: self.dataSheetController.isEditing animated: YES];
    [self updateNavigationButtons];
    [self.view endEditing: YES];
}

- (void) leftButtonPressed: (id) sender {
    [self.dataSheetController cancelEditing: nil];
    [self updateNavigationButtons];
    [self.view endEditing: YES];
}

#pragma mark - Datasheet Controller Delegate

- (void) controllerDidChangeObject:(DatasheetController *)controller {
    [self updateNavigationButtons];
    if (self.dataSheetController.isEditing != self.isEditing) {
        [self setEditing: self.dataSheetController.isEditing animated: YES];
    }
    self.navigationItem.title = NSLocalizedString(controller.title, nil);
}

- (void) controllerWillChangeContent: (DatasheetController*) controller {
    [self.tableView beginUpdates];
}

- (void) controller: (DatasheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath {
    //NSLog(@"DatasheetController:didChangeObject path %@ type %@ newIndexPath %@", indexPath, type==DatasheetChangeDelete ? @"DatasheetChangeDelete" : type==DatasheetChangeInsert ? @"DatasheetChangeInsert" : type==DatasheetChangeUpdate ? @"DatasheetChangeUpdate" : @"???", newIndexPath);
    
    switch(type) {
        case DatasheetChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeUpdate:
            [self configureCell: (DatasheetCell*)[self.tableView cellForRowAtIndexPath:indexPath] withItem: [controller itemAtIndexPath: indexPath] forRowAtIndexPath: indexPath];
            break;
        default:
            break;
    }
}

- (void) controller: (DatasheetController*) controller didChangeSection: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type {
    //NSLog(@"DatasheetController:didChangeSection path %@ type %@", indexPath, type==DatasheetChangeDelete ? @"DatasheetChangeDelete" : type==DatasheetChangeInsert ? @"DatasheetChangeInsert" :   @"???");
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

- (void) controllerDidFinish:(DatasheetController *)controller {
    [self.navigationController popViewControllerAnimated: YES];
}

- (void) controllerDidChangeTitle: (DatasheetController*) controller {
    self.navigationItem.title = NSLocalizedString(controller.title, nil);
    if (self.dataSheetController.backButtonTitle) {
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: self.dataSheetController.backButtonTitle style: UIBarButtonItemStylePlain target:nil action:nil];
    }
}

- (void) makeFirstResponder: (NSIndexPath*) indexPath {
    id cell = [self.tableView cellForRowAtIndexPath: indexPath];
    if ([cell respondsToSelector: @selector(valueView)]) {
        [[cell valueView] becomeFirstResponder];
    }
}

#pragma mark - Datasheet Cell Delegate

- (void) datasheetCell:(DatasheetCell *)cell didChangeValueForView:(id)valueView {
    NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: indexPath];
    if ([valueView isKindOfClass: [UITextField class]]) {
        item.currentValue = [valueView text];
    } else if ([valueView isKindOfClass: [UISwitch class]]) {
        item.currentValue = @([valueView isOn]);
    }
    self.navigationItem.rightBarButtonItem.enabled = [self.dataSheetController allItemsValid];
}

- (BOOL) datasheetCell: (DatasheetCell*) cell shouldChangeValue: (id) oldValue toNewValue: (id) newValue {
    DatasheetItem * item = [self.dataSheetController itemAtIndexPath: [self.tableView indexPathForCell: cell]];
    if (item.changeValidator) {
        return item.changeValidator(oldValue, newValue);
    }
    return YES;
}

#pragma mark - Accessors

- (id) inspectedObject {
    return self.dataSheetController.inspectedObject;
}

- (void) setInspectedObject: (id) inspectedObject {
    if (INSPECTION_DEBUG) NSLog(@"DatasheetViewController:setInspectedObject %@", [inspectedObject class]);
    self.dataSheetController.inspectedObject = inspectedObject;
}

#pragma mark - Background Image Handling

- (UIImageView*) backgroundImageView {
    if (! _backgroundImageView && self.tableView) {
        _backgroundImageView = [[UIImageView alloc] initWithFrame: self.tableView.tableHeaderView.bounds];
        _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        _backgroundImageView.layer.masksToBounds = YES;
        _backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
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
