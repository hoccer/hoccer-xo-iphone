//
//  SettingsViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsViewController.h"

#import "IASKSpecifierValuesViewController.h"

#import "UIViewController+HXOSideMenu.h"
#import "RadialGradientView.h"
#import "UserDefaultsCells.h"


@interface HXOSpecifierValuesViewController : IASKSpecifierValuesViewController

@end

@implementation SettingsViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];

    self.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [super tableView: tableView cellForRowAtIndexPath: indexPath];
    [UserDefaultsCell configureGroupedCell: cell forPosition: indexPath.row inSectionWithCellCount: [self tableView: tableView numberOfRowsInSection: indexPath.section]];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    return cell;
}

- (IASKSpecifierValuesViewController*) specifierValuesViewControllerForSettingsViewController:(IASKAppSettingsViewController *)sender {
    return [[HXOSpecifierValuesViewController alloc] initWithTableClass: sender.tableView.class];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    
}

@end

@implementation HXOSpecifierValuesViewController

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [super tableView: tableView cellForRowAtIndexPath: indexPath];
    [UserDefaultsCell configureGroupedCell: cell forPosition: indexPath.row inSectionWithCellCount: [self tableView: tableView numberOfRowsInSection: indexPath.section]];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    return cell;
}

@end