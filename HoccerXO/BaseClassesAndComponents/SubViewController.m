//
//  SubViewController.m
//  HoccerXO
//
//  Created by David Siegel on 26.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SubViewController.h"

// Workaround for apple bug regarding child view controllers and automatic contentInset adjustments
// See https://github.com/hoccer/hoccer-xo-iphone/issues/239
// and http://stackoverflow.com/questions/19065157/ios-7-custom-container-view-controller-and-content-inset
// and http://stackoverflow.com/questions/19038949/content-falls-beneath-navigation-bar-when-embedded-in-custom-container-view-cont

@implementation SubViewController

/*
- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (parent) {
        CGFloat top = parent.topLayoutGuide.length;
        CGFloat bottom = parent.bottomLayoutGuide.length;
        if (self.tableView.contentInset.top != top) {
            UIEdgeInsets newInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
            self.tableView.contentInset = newInsets;
            self.tableView.scrollIndicatorInsets = newInsets;
        }
    }
    [super didMoveToParentViewController:parent];
}
*/
@end
