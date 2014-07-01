//
//  BatchInviteViewController.m
//  HoccerXO
//
//  Created by David Siegel on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "BatchInviteViewController.h"

#import <AddressBook/AddressBook.h>

#import "AppDelegate.h"

@interface BatchInviteViewController ()

@property (nonatomic, strong) PeopleMultiPickerViewController * peoplePicker;
@end

@implementation BatchInviteViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.peoplePicker = (PeopleMultiPickerViewController*)self.topViewController;
    self.peoplePicker.mode = self.mode;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    UIViewController * vc = nil;
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
        CFErrorRef error;
        ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
            [self setViewControllers: @[[self rootViewForAuthorizationStatus: granted]] animated: YES];
        });
    } else {
        vc = [self rootViewForAuthorizationStatus: ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized];
    }

    [self setViewControllers: vc ? @[vc] : nil];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController*) rootViewForAuthorizationStatus: (BOOL) granted {
    AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    return granted ? self.peoplePicker : self.mode == PeoplePickerModeMail ? appDelegate.mailPicker : appDelegate.smsPicker;
}

- (void) setMode:(PeoplePickerMode)mode {
    self.peoplePicker.mode = mode;
    _mode = mode;
}

@end
