//
//  GroupViewController.m
//  HoccerXO
//
//  Created by David Siegel on 17.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupViewController.h"

#import "Group.h"
#import "HXOBackend.h"
#import "AppDelegate.h"

typedef enum GroupViewControllerModes {
    kHXOGroupViewControllerModeCreateGroup,
    kHXOGroupViewControllerModeEditGroup,
    kHXOGroupViewControllerModeViewGroup
} GroupViewControllerMode;

@interface GroupViewController () {
    GroupViewControllerMode _mode;
}

@end

@implementation GroupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    if (_group == nil) {
        _mode = kHXOGroupViewControllerModeCreateGroup;
    } else { // TODO: if I'm admin...
        _mode = kHXOGroupViewControllerModeEditGroup;
    }
    [self setupNavigationButtons];
}

- (void) setupNavigationButtons {
    if (_mode == kHXOGroupViewControllerModeCreateGroup) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action:@selector(onDone:)];
    } else if (_mode == kHXOGroupViewControllerModeEditGroup) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemEdit target: self action:@selector(onEdit:)];
    } else {
        NSLog(@"setupNavigationButtons: unhandled mode %d", _mode);
    }
}

- (void) onCancel: (id) sender {
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) onDone: (id) sender {
    [self saveGroup];
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) onEdit: (id) sender {
    NSLog(@"GroupView onEdit");
}

- (void) saveGroup {
    if (_mode == kHXOGroupViewControllerModeCreateGroup) {
        Group * group = [self.backend createGroup];
        group.nickName = @"Tolle Gruppe";
    } else {
        NSLog(@"saveGroup: unhandled mode %d", _mode);
    }
}

- (HXOBackend*) backend {
    return ((AppDelegate*)UIApplication.sharedApplication.delegate).chatBackend;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return _items.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_items[section] count];
}


@end
