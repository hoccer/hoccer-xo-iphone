//
//  HXONavigationItem.m
//  HoccerXO
//
//  Created by David Siegel on 18.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXONavigationItem.h"

@implementation HXONavigationItem

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self createTitleView];
    }
    return self;
}

- (void) createTitleView {
    self.titleView = [[UIView alloc] init];
}

@end
