//
//  NSData+HexString.m
//  HoccerTalk
//
//  Created by David Siegel on 29.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NSData+HexString.h"

@implementation NSData (HexString)

- (NSString *)hexadecimalString {
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */

    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer)
        return [NSString string];

    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02x", (unsigned int)dataBuffer[i]]];

    return [NSString stringWithString:hexString];
}

@end
