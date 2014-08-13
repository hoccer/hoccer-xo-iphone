//
//  AddToCollectionListViewControllerDelegate.h
//  HoccerXO
//
//  Created by Guido Lorenz on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AddToCollectionListViewController;
@class Collection;
@protocol AddToCollectionListViewControllerDelegate <NSObject>

- (void) addToCollectionListViewController:(AddToCollectionListViewController *)controller didSelectCollection:(Collection *)collection;

@end
