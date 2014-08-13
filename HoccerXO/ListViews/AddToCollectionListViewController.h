//
//  AddToCollectionListViewController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CollectionListViewController.h"

@protocol AddToCollectionListViewControllerDelegate;

@interface AddToCollectionListViewController : CollectionListViewController

@property (nonatomic, strong) id<AddToCollectionListViewControllerDelegate> addToCollectionListViewControllerDelegate;

@end
