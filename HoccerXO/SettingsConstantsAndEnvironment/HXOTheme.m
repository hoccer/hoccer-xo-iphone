//
//  HXOTheme.m
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTheme.h"

static HXOTheme * _currentTheme;

@implementation HXOTheme

#pragma mark - zutrinken land

- (UIColor*) navigationBarTintColor {
    return [UIColor colorWithRed: 37.0 / 255 green: 184.0 / 255 blue: 171.0 / 255 alpha: 1.0];
}

#pragma mark - agnat land

+ (void) initialize {
    _currentTheme = [[HXOTheme alloc] init];
}

+ (id) theme {
    return _currentTheme;
}

- (void) setupAppearanceProxies {
    [[UINavigationBar appearance] setBarTintColor: self.navigationBarTintColor];
    [[UINavigationBar appearance] setBarStyle:     UIBarStyleBlackTranslucent];
    [[UINavigationBar appearance] setTintColor:    [UIColor whiteColor]];
}

@end
