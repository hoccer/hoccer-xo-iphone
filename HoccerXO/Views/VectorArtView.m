//
//  VectorArtView.m
//  HoccerXO
//
//  Created by David Siegel on 12.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "VectorArtView.h"

@implementation VectorArtView

- (id)initWithBezierPath: (UIBezierPath*) path {
    self = [super initWithFrame:path.bounds];
    if (self) {
        self.shape = [CAShapeLayer layer];
        self.shape.path = path.CGPath;
        [self.layer addSublayer: self.shape];
    }
    return self;
}

+ (id) disclosureArrow {
    //// Bezier Drawing
    UIBezierPath* bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint: CGPointMake(8.7, 7)];
    [bezierPath addLineToPoint: CGPointMake(1.8, 13.9)];
    [bezierPath addLineToPoint: CGPointMake(0.2, 12.2)];
    [bezierPath addLineToPoint: CGPointMake(5.5, 6.9)];
    [bezierPath addLineToPoint: CGPointMake(0, 1.7)];
    [bezierPath addLineToPoint: CGPointMake(1.7, 0)];
    [bezierPath addLineToPoint: CGPointMake(8.7, 7)];
    [bezierPath closePath];
    bezierPath.miterLimit = 4;

    VectorArtView * va = [[VectorArtView alloc] initWithBezierPath: bezierPath];
    va.shape.strokeColor = nil;
    va.shape.fillColor = [UIColor colorWithRed: 0.172 green: 0.705 blue: 0.642 alpha: 1].CGColor;
    return va;
    
}

@end
