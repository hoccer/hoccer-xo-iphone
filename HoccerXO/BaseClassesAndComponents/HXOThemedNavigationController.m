//
//  HXOThemedNavigationController.m
//  HoccerXO
//
//  Created by David Siegel on 03.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOThemedNavigationController.h"

#define DEBUG_ROTATION NO

@implementation HXOThemedNavigationController

- (BOOL) shouldAutorotate {
    BOOL should = [[self.viewControllers lastObject] shouldAutorotate];
    if (DEBUG_ROTATION) NSLog(@"HXOThemedNavigationController:shouldAutorotate:%d %@", should, self.viewControllers.lastObject);
    return should;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    UIViewController * vc = [self.viewControllers lastObject];
    if (vc) {

        UIInterfaceOrientationMask supported = [[self.viewControllers lastObject] supportedInterfaceOrientations];
        if (DEBUG_ROTATION) NSLog(@"HXOThemedNavigationController:supportedInterfaceOrientations:%lu %@", (unsigned long)supported, self.viewControllers.lastObject);
        return supported;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
    UIViewController * vc = [self.viewControllers lastObject];
    if (vc) {
        UIInterfaceOrientation preferred = [vc preferredInterfaceOrientationForPresentation];
        if (DEBUG_ROTATION) NSLog(@"HXOThemedNavigationController:preferredInterfaceOrientationForPresentation:%lu %@", (long)preferred, self.viewControllers.lastObject);
        return preferred;
    } else {
        return UIInterfaceOrientationPortrait;
    }
}

@end
