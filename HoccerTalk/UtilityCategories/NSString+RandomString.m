//
//  NSString+RandomString.m
//  HoccerTalk
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NSString+RandomString.h"


static const NSString * const kDefaultRandomStringCharacterSet =
@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!§$%&/()[]{}<>#:;,.*+-_^=?\"' \t";


@implementation NSString (RandomString)

+ (NSString*) stringWithRandomCharactersOfLength: (NSUInteger) length {
    return [NSString stringWithRandomCharactersOfLength: length usingCharacterSet: kDefaultRandomStringCharacterSet];
}

+ (NSString*) stringWithRandomCharactersOfLength: (NSUInteger) length usingCharacterSet: (const NSString* const) characterSet {
    NSMutableString *randomString = [NSMutableString stringWithCapacity: length];
    NSMutableData * randomness = [NSMutableData dataWithLength: length];
    SecRandomCopyBytes(kSecRandomDefault, length, [randomness mutableBytes]);

    for (int i=0; i<length; i++) {
        const uint8_t randomNumber = ((const uint8_t*)[randomness bytes])[i];
        char randomChar = [characterSet characterAtIndex: randomNumber % [characterSet length]];
        [randomString appendFormat: @"%c", randomChar];
    }
    return [randomString copy];
}

@end
