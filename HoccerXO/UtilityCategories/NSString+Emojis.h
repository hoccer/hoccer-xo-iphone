//
//  NSString+Emojis.h
//  HoccerXO
//
//  Created by David Siegel on 04.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Emojis)

- (void) enumerateEmojiRangesUsingBlock: (void(^)(NSRange emojiRange)) block;

@end
