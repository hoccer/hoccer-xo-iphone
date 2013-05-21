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
#import "UserDefaultsCells.h"


@interface GroupViewController ()
{
    BOOL _isNewGroup;
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
    [self setupNavigationButtons];
    _isNewGroup = self.group == nil;
    if (self.group == nil) {
        NSLog(@"creating new Group");
        self.group = [self.backend createGroup];
        [self setupContactKVO];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    if (_mode == ProfileViewModeNewGroup && ! self.isEditing) {
        [self setEditing: YES animated: YES];
    }
}

- (void) configureMode {
    if (self.group == nil) {
        _mode = ProfileViewModeNewGroup;
    } else { // TODO: if I'm admin...
        _mode = ProfileViewModeEditGroup;
    }
}

- (void) setGroup:(Group *)group {
    self.contact = group;
}

- (Group*) group {
    if ([self.contact isKindOfClass: [Group class]]) {
        return (Group*) self.contact;
    }
    return nil;
}

- (id) getModelObject {
    return self.group;
}

- (NSString*) avatarDefaultImageName {
    return @"avatar_default_group"; // @"avatar_default_group_large";
}

- (NSString*) navigationItemTitleKey {
    switch (_mode) {
        case ProfileViewModeNewGroup:
            return @"navigation_title_new_group";
        case ProfileViewModeEditGroup:
        case ProfileViewModeShowGroup:
            return @"navigation_title_group";
        default:
            return @"navigation_title_unhandled_mode";
    }
}

- (void) setupNavigationButtons {
    if (_mode == ProfileViewModeNewGroup) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    } else if (_mode == ProfileViewModeEditGroup) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        if (self.isEditing) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
        } else {
            self.navigationItem.leftBarButtonItem = nil;
        }
    } else {
        NSLog(@"setupNavigationButtons: unhandled mode %d", _mode);
    }
}

- (void) onEditingDone {
    if (_mode == ProfileViewModeNewGroup) {
        if (_canceled) {
            NSManagedObjectContext * moc = self.appDelegate.managedObjectContext;
            [moc deleteObject: self.group];
        }
        [self dismissViewControllerAnimated: YES completion: nil];
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

- (void) configureTrailingEditOnlySections: (BOOL) editing {
}

- (NSArray*) composeItems: (NSArray*) items withEditFlag: (BOOL) editing {
    if (editing) {
        return @[ @[_avatarItem], items];
    } else {
        return @[ @[_avatarItem], items];
    }
}

@end
