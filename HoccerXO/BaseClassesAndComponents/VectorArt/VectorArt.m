//
//  VectorArt.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "VectorArt.h"

@implementation VectorArt

- (id) init {
    self = [super init];
    if (self) {
        self.path = [UIBezierPath bezierPath];
        [self initPath];
    }
    return self;
}

- (void) initPath {
}

- (UIImage*) image {
    CGRect frame = CGRectInset(self.path.bounds, -self.path.lineWidth, -self.path.lineWidth);
    return [self imageWithFrame: frame];
}

- (UIImage*) imageWithFrame: (CGRect) frame {
    UIView *view = [[UIView alloc] initWithFrame: frame];
    view.clipsToBounds = NO;
    UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, [[UIScreen mainScreen] scale]);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    //CGContextRef context = UIGraphicsGetCurrentContext();
    //CGContextTranslateCTM(context, -(self.path.bounds.origin.x), -(self.path.bounds.origin.y));

    if (self.fillColor) {
        [self.fillColor setFill];
        [self.path fill];
    }
    if (self.strokeColor) {
        [self.strokeColor setStroke];
        [self.path stroke];
    }
    UIImage * image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIBezierPath*) pathScaledToSize: (CGSize) size {
    UIBezierPath * path = [self.path copy];
    CGRect pathBounds = path.bounds;
    CGSize pathSize = CGSizeMake(CGRectGetMaxX(pathBounds), CGRectGetMaxY(pathBounds));


    CGFloat scale;
    if (pathSize.width > pathSize.height) {
        scale = size.width / pathSize.width;
    } else {
        scale = size.height / pathSize.height;
    }
    CGAffineTransform transform = CGAffineTransformMakeScale(scale, scale);
    [path applyTransform: transform];
    return path;
}
@end
