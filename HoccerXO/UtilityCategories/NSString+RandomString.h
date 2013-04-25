//
//  NSString+RandomString.h
//  HoccerXO
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (RandomString)

+ (NSString*) stringWithRandomCharactersOfLength: (NSUInteger) length;
+ (NSString*) stringWithRandomCharactersOfLength: (NSUInteger) length usingCharacterSet: (const NSString* const) characterSet;


@end
