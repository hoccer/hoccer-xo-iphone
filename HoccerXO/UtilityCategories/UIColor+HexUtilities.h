//
//  UIColor+HexUtilities.h
//  HoccerXO
//
//  Created by David Siegel on 27.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (HexUtilities)

/* CSS style hex string converstion:
 * #0        -> #000000ff
 * #aa       -> #aaaaaaff
 * #0f0      -> #00ff00ff
 * #0f0f     -> #00ff00ff
 * #aabbcc   -> #aabbccff
 * #aabbccdd -> #aabbccdd
 */
+ (UIColor *)colorWithHexString:(NSString*) string;
+ (UIColor *)colorWithHex: (UInt32) color;

@end
