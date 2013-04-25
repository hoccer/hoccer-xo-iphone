//
//  UIViewController+HXOSideMenuButtons.h
//  HoccerTalk
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (HXOSideMenuButtons)

- (UIBarButtonItem*) hoccerTalkMenuButton;
- (UIBarButtonItem*) hoccerTalkContactsButton;

- (void) setNavigationBarBackgroundWithLines;
- (void) setNavigationBarBackgroundPlain;

@end
