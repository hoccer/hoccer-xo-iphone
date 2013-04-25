//
//  NonFloatingSectionHeaderTableView.m
//  HoccerTalk
//
//  Created by David Siegel on 05.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NonFloatingSectionHeaderTableView.h"

@implementation NonFloatingSectionHeaderTableView


- (BOOL) allowsHeaderViewsToFloat {
    return NO;
}

- (BOOL) allowsFooterViewsToFloat {
    return NO;
}

@end
