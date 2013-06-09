//
//  NavigationMenuViewController.h
//  HoccerXO
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#ifdef NEW_MFSIDEMENU
#import "MFSideMenu.h"
#else
@class MFSideMenu;
#endif

@interface NavigationMenuViewController : UITableViewController <UINavigationControllerDelegate>

#ifdef NEW_MFSIDEMENU
@property (nonatomic, assign) MFSideMenuContainerViewController *sideMenu;
#else
@property (nonatomic, assign) MFSideMenu *sideMenu;
#endif

- (void) cacheViewController: (UIViewController*) viewController withStoryboardId: (NSString*) storyboardId;

@end
