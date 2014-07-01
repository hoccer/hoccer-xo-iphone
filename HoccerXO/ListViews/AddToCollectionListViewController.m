//
//  AddToCollectionListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AddToCollectionListViewController.h"

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

@end
