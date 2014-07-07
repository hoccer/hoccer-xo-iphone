//
//  ContactPickerViewController.m
//  HoccerXO
//
//  Created by David Siegel on 10.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactPicker.h"
#import "Contact.h"
#import "ContactCell.h"

#import "SmallContactCell.h"

#import "HXOThemedNavigationController.h"

@interface ContactPicker ()

@property (nonatomic, strong) NSMutableArray * pickedContacts;

@end

@implementation ContactPicker

+ (id) contactPickerWithTitle: (NSString*)               title
                        style: (ContactPickerStyle)      style
                    predicate: (NSPredicate *)           predicate
                   completion: (ContactPickerCompletion) completion
{

    ContactPicker * picker = [[ContactPicker alloc] init];
    picker.pickerStyle = style;
    picker.completion = completion;
    picker.title = title;
    picker.predicate = predicate;

    UINavigationController * modalPresentationHelper = [[HXOThemedNavigationController alloc] initWithRootViewController: picker];

    return modalPresentationHelper;
}

- (id) init {
    self = [super initWithStyle: UITableViewStylePlain];
    if (self) {
    }
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];

    self.pickedContacts = [NSMutableArray array];

    self.navigationItem.title = self.title;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(done:)];

    if (self.pickerStyle == ContactPickerStyleMulti) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action: @selector(done:)];
    }
}

- (void) done: (id) sender {
    id result = nil;
    if ( ! [sender isEqual: self.navigationItem.leftBarButtonItem]) { // not cacneled
        if (self.pickerStyle == ContactPickerStyleMulti) {
            result = [self.pickedContacts copy];

        } else {
            result = [self.pickedContacts firstObject];
        }
    }
    [self.pickedContacts removeAllObjects];
    if (self.completion) {
        self.completion(result);
    }
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) addPredicates:(NSMutableArray *)predicates {
    if (self.predicate) {
        [predicates addObject: self.predicate];
    }
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Contact * contact = [self.currentFetchedResultsController objectAtIndexPath: indexPath];
    if ([self.pickedContacts indexOfObject: contact] == NSNotFound) {
        [self.pickedContacts addObject: contact];
    } else {
        [self.pickedContacts removeObject: contact];
    }
    [self configureCell: [self.tableView cellForRowAtIndexPath:indexPath] atIndexPath: indexPath];
    if (self.pickerStyle == ContactPickerStyleSingle && self.pickedContacts.count == 1) {
        [self done: self];
    }
}

- (void) configureCell:(UITableViewCell<ContactCell>*)cell atIndexPath:(NSIndexPath *)indexPath {
    [super configureCell: cell atIndexPath: indexPath];
    cell.subtitleLabel.text = nil;
    cell.accessoryType = [self.pickedContacts indexOfObject: [self.currentFetchedResultsController objectAtIndexPath: indexPath]] == NSNotFound ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
}

- (id) cellClass {
    return [SmallContactCell class];
}

- (NSString*) placeholderText  { return nil; }
- (UIImage*)  placeholderImage { return nil; }

@end
