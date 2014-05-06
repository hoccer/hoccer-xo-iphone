//
//  CustomKeyViewController.m
//  HoccerXO
//
//  Created by David Siegel on 06.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CustomKeyViewController.h"

@interface CustomKeyViewController ()

@property (strong) UISegmentedControl * generateOrImportSelector;

@end

@implementation CustomKeyViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.generateOrImportSelector = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"key_custom_generate_nav_title", nil), NSLocalizedString( @"key_custom_import_nav_title", nil)]];
    self.navigationItem.titleView = self.generateOrImportSelector;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.

}

@end
