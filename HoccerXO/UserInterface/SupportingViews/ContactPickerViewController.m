//
//  ContactPickerViewController.m
//  HoccerXO
//
//  Created by David Siegel on 10.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactPickerViewController.h"

#import "HXOThemedNavigationController.h"

@implementation ContactPickerViewController

+ (id) contactPickerForTypes: (NSUInteger) typeMask style: (ContactPickerStyle) style completion: (ContactPickerCompletion) completion {

    ContactPickerViewController * picker = [[ContactPickerViewController alloc] initWithStyle: UITableViewStylePlain];
    picker.pickerStyle = style;
    picker.completion = completion;

    UINavigationController * modalPresentationHelper = [[HXOThemedNavigationController alloc] initWithRootViewController: picker];

    return modalPresentationHelper;
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
    }
    if (self.completion) {
        self.completion(result);
    }
}

@end
