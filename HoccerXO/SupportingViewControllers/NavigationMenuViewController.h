//
//  NavigationMenuViewController.h
//  HoccerXO
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOSideMenuViewController.h"

@interface NavigationMenuViewController : HXOSideMenuViewController <UINavigationControllerDelegate>

@property (nonatomic,assign) IBOutlet UITableView* tableView;

- (void) cacheViewController: (UIViewController*) viewController withStoryboardId: (NSString*) storyboardId;

@end
