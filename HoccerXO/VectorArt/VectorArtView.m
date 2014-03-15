//
//  VectorArtView.m
//  HoccerXO
//
//  Created by David Siegel on 12.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "VectorArtView.h"

#import "VectorArt.h"

@interface VectorArtView ()

@property (nonatomic,readonly) CAShapeLayer* shapeLayer;

@end

@implementation VectorArtView

- (id)initWithVectorArt: (VectorArt *) shape {
    self = [super initWithFrame: shape.path.bounds];
    if (self) {
        _shapeLayer = [CAShapeLayer layer];
        [self.layer addSublayer: self.shapeLayer];
        self.shape = shape;
    }
    return self;
}

- (void) setShape:(VectorArt *)shape {
    _shape = shape;
    self.shapeLayer.path        = shape.path.CGPath;
    self.shapeLayer.fillColor   = shape.fillColor.CGColor;
    self.shapeLayer.strokeColor = shape.strokeColor.CGColor;

}

@end
