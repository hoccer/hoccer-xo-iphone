//
//  HXOLabel.m
//  HoccerXO
//
//  Created by David Siegel on 05.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOLabel.h"

@implementation HXOLabel

- (CGSize) intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    s.height += 1;
    return s;
}

@end
