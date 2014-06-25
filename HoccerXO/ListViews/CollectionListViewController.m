//
//  CollectionListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 25.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CollectionListViewController.h"

@interface CollectionListViewController ()

@end

@implementation CollectionListViewController

#pragma mark - Lifecycle

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSString *title = NSLocalizedString(@"collection_list_nav_title", nil);
    self.navigationItem.title = title;
}

@end
