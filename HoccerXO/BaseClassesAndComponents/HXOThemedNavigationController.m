//
//  HXOThemedNavigationController.m
//  HoccerXO
//
//  Created by David Siegel on 03.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOThemedNavigationController.h"

@implementation HXOThemedNavigationController

- (void)awakeFromNib {
    self.navigationBar.translucent = NO;
}

- (BOOL) shouldAutorotate {
    return [[self.viewControllers lastObject] shouldAutorotate];
}

- (NSUInteger) supportedInterfaceOrientations {
    return [[self.viewControllers lastObject] supportedInterfaceOrientations];
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
    return [[self.viewControllers lastObject] preferredInterfaceOrientationForPresentation];
}

@end