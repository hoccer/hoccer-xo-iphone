//
//  DisclosureArrow.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DisclosureArrow.h"

@implementation DisclosureArrow

- (void) initPath {
    [self.path moveToPoint: CGPointMake(8.7, 7)];
    [self.path addLineToPoint: CGPointMake(1.8, 13.9)];
    [self.path addLineToPoint: CGPointMake(0.2, 12.2)];
    [self.path addLineToPoint: CGPointMake(5.5, 6.9)];
    [self.path addLineToPoint: CGPointMake(0, 1.7)];
    [self.path addLineToPoint: CGPointMake(1.7, 0)];
    [self.path addLineToPoint: CGPointMake(8.7, 7)];
    [self.path closePath];
    self.path.miterLimit = 4;
    
    self.strokeColor = nil;
    self.fillColor = [[HXOTheme theme] cellAccessoryColor];
}

@end
