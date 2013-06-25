//
//  UIViewController+HXOSideMenuButtons.h
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MFSideMenuContainerViewController;

@interface UIViewController (HXOSideMenu)

- (UIBarButtonItem*) hxoMenuButton;
- (UIBarButtonItem*) hxoContactsButton;

- (void) setNavigationBarBackgroundWithLines;
- (void) setNavigationBarBackgroundPlain;

- (MFSideMenuContainerViewController*) menuContainerViewController;

@end
