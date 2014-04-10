//
//  PaperDart.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "PaperDart.h"

@implementation PaperDart

- (void) initPath {
    UIBezierPath * bezierPath = self.path;

    [bezierPath moveToPoint: CGPointMake(0, 8.1)];
    [bezierPath addLineToPoint: CGPointMake(7, 9.1)];
    [bezierPath addLineToPoint: CGPointMake(7.8, 18)];
    [bezierPath addLineToPoint: CGPointMake(15.1, 11.8)];
    [bezierPath addLineToPoint: CGPointMake(24.4, 15.1)];
    [bezierPath addLineToPoint: CGPointMake(27, 0)];
    [bezierPath addLineToPoint: CGPointMake(0, 8.1)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(12.2, 9.9)];
    [bezierPath addLineToPoint: CGPointMake(8.5, 16.4)];
    [bezierPath addLineToPoint: CGPointMake(8.5, 9.1)];
    [bezierPath addLineToPoint: CGPointMake(25.8, 1)];
    [bezierPath addLineToPoint: CGPointMake(12.2, 9.9)];
    [bezierPath closePath];

    self.fillColor = [UIColor blackColor];
}
@end
