//
//  ProfileViewTabItemHelper.m
//  HoccerXO
//
//  Created by David Siegel on 15.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ProfileViewTabItemHelper.h"

#import "tab_profile.h"

@implementation ProfileViewTabItemHelper

- (void) awakeFromNib {
    [super awakeFromNib];
    self.title = NSLocalizedString(@"profile_nav_title", nil);
    self.tabBarItem.image = [[tab_profile alloc] init].image;
}

@end
