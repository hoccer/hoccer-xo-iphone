//
//  ContactPickerViewController.m
//  HoccerXO
//
//  Created by David Siegel on 10.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactPickerViewController.h"
#import "Contact.h"
#import "ContactCell.h"

#import "SmallContactCell.h"

#import "HXOThemedNavigationController.h"

@implementation ContactPickerViewController

+ (id) contactPickerWithTitle:(NSString *)title types:(NSUInteger)typeMask style:(ContactPickerStyle)style completion:(ContactPickerCompletion)completion {

    ContactPickerViewController * picker = [[ContactPickerViewController alloc] init];
    picker.navigationItem.prompt = title;
    picker.pickerStyle = style;
    picker.completion = completion;

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

    self.navigationItem.title = nil;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(done:)];

    if (self.pickerStyle == ContactPickerStyleMulti) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action: @selector(done:)];
    }
}

- (void) done: (id) sender {
    id result = nil;
    if ( ! [sender isEqual: self.navigationItem.leftBarButtonItem]) {
        if (self.pickerStyle == ContactPickerStyleMulti) {

        } else {
            result = [self.currentFetchedResultsController objectAtIndexPath: sender];
        }
    }
    if (self.completion) {
        self.completion(result);
    }
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.pickerStyle == ContactPickerStyleMulti) {
    } else {
        [self done: indexPath];
    }
}

- (id) cellClass {
    return [SmallContactCell class];
}

@end
