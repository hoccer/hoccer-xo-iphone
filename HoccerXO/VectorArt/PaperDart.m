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

    [bezierPath moveToPoint: CGPointMake(18.5, 11.5)];
    [bezierPath addLineToPoint: CGPointMake(11.5, 9.5)];
    [bezierPath addLineToPoint: CGPointMake(6, 15)];
    [bezierPath addLineToPoint: CGPointMake(6, 8)];
    [bezierPath addLineToPoint: CGPointMake(0.5, 6.5)];
    [bezierPath addLineToPoint: CGPointMake(21.5, 0.5)];
    [bezierPath addLineToPoint: CGPointMake(18.5, 11.5)];
    [bezierPath closePath];
    [bezierPath moveToPoint: CGPointMake(18, 3)];
    [bezierPath addLineToPoint: CGPointMake(7, 8)];
    [bezierPath addLineToPoint: CGPointMake(7, 13)];
    [bezierPath addLineToPoint: CGPointMake(9, 9)];
    [bezierPath addLineToPoint: CGPointMake(18, 3)];
    [bezierPath closePath];

    self.fillColor = [UIColor blackColor];
}
@end
