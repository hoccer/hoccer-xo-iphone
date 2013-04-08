//
//  UIImage+ScaleAndCrop.h
//  HoccerTalk
//
//  Created by David Siegel on 30.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (ScaleAndCrop)

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize;
- (void)drawInRect:(CGRect)drawRect fromRect:(CGRect)fromRect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;

@end
