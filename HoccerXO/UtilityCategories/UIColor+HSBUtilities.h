//
//  UIColor+HSBUtilities.h
//  HoccerXO
//
//  Created by David Siegel on 27.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (HSBUtilities)

- (UIColor*) multiplyHue: (CGFloat) hf saturation: (CGFloat) sf brightness: (CGFloat) bf alpha: (CGFloat) af;
- (UIColor*) multiplyHue: (CGFloat) hf saturation: (CGFloat) sf brightness: (CGFloat) bf;
- (UIColor*) multiplyHSBA: (UIColor*) color;

- (UIColor*) lighten;
- (UIColor*) darken;

@end
