//
//  NSString+Emojis.m
//  HoccerXO
//
//  Created by David Siegel on 04.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NSString+Emojis.h"

@implementation NSString (Emojis)

- (void) enumerateEmojiRangesUsingBlock: (void(^)(NSRange emojiRange)) block {
    __block BOOL previousIsEmoji = NO;
    __block NSUInteger rangeStart = 0;

    // found at https://gist.github.com/cihancimen/4146056
    [self enumerateSubstringsInRange:NSMakeRange(0, [self length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:
     ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         BOOL isEmoji = NO;
         const unichar hs = [substring characterAtIndex:0];
         // surrogate pair
         if (0xd800 <= hs && hs <= 0xdbff) {
             if (substring.length > 1) {
                 const unichar ls = [substring characterAtIndex:1];
                 const int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                 if (0x1d000 <= uc && uc <= 0x1f77f) {
                     isEmoji = YES;
                 }
             }
         } else if (substring.length > 1) {
             const unichar ls = [substring characterAtIndex:1];
             if (ls == 0x20e3) {
                 isEmoji = YES;
             }

         } else {
             // non surrogate
             if (0x2100 <= hs && hs <= 0x27ff) {
                 isEmoji = YES;
             } else if (0x2B05 <= hs && hs <= 0x2b07) {
                 isEmoji = YES;
             } else if (0x2934 <= hs && hs <= 0x2935) {
                 isEmoji = YES;
             } else if (0x3297 <= hs && hs <= 0x3299) {
                 isEmoji = YES;
             } else if (hs == 0xa9 || hs == 0xae || hs == 0x303d || hs == 0x3030 || hs == 0x2b55 || hs == 0x2b1c || hs == 0x2b1b || hs == 0x2b50) {
                 isEmoji = YES;
             }
         }
         if (isEmoji && ! previousIsEmoji) {
             rangeStart = substringRange.location;
         } else if ( ! isEmoji && previousIsEmoji) {
             block(NSMakeRange(rangeStart, substringRange.location - rangeStart));
         }
         previousIsEmoji = isEmoji;
     }];
}
@end
