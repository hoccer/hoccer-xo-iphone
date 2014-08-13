//
//  NSString+EnumerateRanges.h
//  HoccerXO
//
//  Created by Guido Lorenz on 09.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (EnumerateRanges)

- (void) enumerateRangesOfString:(NSString *)string options:(NSStringCompareOptions)options usingBlock:(void (^)(NSRange range))block;

@end
