//
//  HXOSideMenuViewController.m
//  HoccerXO
//
//  Created by David Siegel on 25.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOSideMenuViewController.h"

#import "MFSideMenu.h"

@interface HXOSideMenuViewController ()

@end

@implementation HXOSideMenuViewController


- (MFSideMenuContainerViewController*) menuContainerViewController {
    return (MFSideMenuContainerViewController*)self.parentViewController;
}

- (UINavigationController*) navigationController {
    return (UINavigationController*)self.menuContainerViewController.centerViewController;
}


@end
