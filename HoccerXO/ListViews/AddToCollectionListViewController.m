//
//  AddToCollectionListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AddToCollectionListViewController.h"

#import "AddToCollectionListViewControllerDelegate.h"

@interface AddToCollectionListViewController ()

@end

@implementation AddToCollectionListViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)];
}

- (void) cancelPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UITableViewCellAccessoryType)cellAccessoryType {
    return UITableViewCellAccessoryNone;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.addToCollectionListViewControllerDelegate) {
        Collection *collection = [self collectionAtIndexPath:indexPath];
        [self.addToCollectionListViewControllerDelegate addToCollectionListViewController:self didSelectCollection:collection];
    }
}

@end
