//
//  GroupsViewController.h
//  HoccerXO
//
//  Created by David Siegel on 15.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ContactListViewController.h"

@class HXOBackend;

@interface GroupListViewController : ContactListViewController

@property (readonly) HXOBackend * backend;

@end
