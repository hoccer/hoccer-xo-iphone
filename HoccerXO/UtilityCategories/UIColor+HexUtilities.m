//
//  UIColor+HexUtilities.m
//  HoccerXO
//
//  Created by David Siegel on 27.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "UIColor+HexUtilities.h"

@implementation UIColor (HexUtilities)

+ (UIColor *)colorWithHexString:(NSString*) string {
    const char *cStr = [string cStringUsingEncoding: NSASCIIStringEncoding];
    unsigned long x = strtoul(cStr+1, NULL, 16);
    
    switch (string.length - 1) {
        case 1: x = (x * 0x11 << 24) | (x * 0x11 << 16) | (x * 0x11 << 8) | 0xff; break;
        case 2: x = (x << 24) | (x << 16) | (x << 8) | 0xff; break;
        case 3: x = (((x >> 8) & 0xf) * 0x11) << 24 | (((x >> 4) & 0xf) * 0x11) << 16 | ((x & 0xf) * 0x11) << 8 | 0xff; break;
        case 4: x = (((x >> 12) & 0xf) * 0x11) << 24 | (((x >> 8) & 0xf) * 0x11) << 16 | (((x >> 4) & 0xf) * 0x11) << 8 |  ((x & 0xf) * 0x11); break;
        case 6: x = (x << 8) | 0xff; break;
        case 8: break;
        default: return nil;
    }
    return [UIColor colorWithHex: x];
}

+ (UIColor *)colorWithHex: (UInt32) color {
    return [UIColor colorWithRed: (float)((color >> 24) & 0xff) / 255.0f
                           green: (float)((color >> 16) & 0xff) / 255.0f
                            blue: (float)((color >> 8) & 0xff)  / 255.0f
                           alpha: (float)(color & 0xff)         / 255.0];
}

@end
