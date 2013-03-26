//
//  NavigationMenuViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MFSideMenu;

@interface NavigationMenuViewController : UITableViewController

@property (nonatomic, assign) MFSideMenu *sideMenu;

- (void) cacheViewController: (UIViewController*) viewController withStoryboardId: (NSString*) storyboardId;

@end
