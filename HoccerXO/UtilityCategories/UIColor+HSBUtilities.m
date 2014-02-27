//
//  UIColor+HSBUtilities.m
//  HoccerXO
//
//  Created by David Siegel on 27.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "UIColor+HSBUtilities.h"

@implementation UIColor (HSBUtilities)


- (UIColor*) multiplyHue: (CGFloat) hf saturation: (CGFloat) sf brightness: (CGFloat) bf alpha: (CGFloat) af {
    CGFloat h, s, b, a;
    if ([self getHue: &h saturation: &s brightness: &b alpha: &a]) {
        h *= hf;
        s *= sf;
        b *= bf;
        a *= af;
        return [[self class] colorWithHue:h saturation: s brightness: b alpha: a];
    }
    return nil;

}

- (UIColor*) multiplyHue: (CGFloat) hf saturation: (CGFloat) sf brightness: (CGFloat) bf {
    return [self multiplyHue: hf saturation: sf brightness: bf alpha: 1.0];
}

- (UIColor*) multiplyHSBA: (UIColor*) color {
    CGFloat h, s, b, a;
    if ([color getHue: &h saturation: &s brightness: &b alpha: &a]) {
        return [self multiplyHue: h saturation: s brightness: b alpha: a];
    }
    return nil;
}

- (UIColor*) lighten {
    return [self multiplyHue: 1.0 saturation: 0.4 brightness: 1.2];
}

- (UIColor*) darken {
    return [self multiplyHue: 1.0 saturation: 0.6 brightness: 0.6];
}


@end
