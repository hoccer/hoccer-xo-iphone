//
//  NSObject+Regexp.m
//  Hoccer
//
//  Created by Robert Palmer on 23.09.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "NSString+Regexp.h"
#import <regex.h>

@implementation NSString (Regexp)

- (BOOL)matches: (NSString *)pattern 
{
	int result;
	regex_t reg;
	
	const char* regex = [pattern UTF8String];
	const char* string = [self UTF8String];
	
	if (regcomp(&reg, regex, REG_EXTENDED | REG_NOSUB) != 0) {
		return NO;
	}
	
	result = regexec(&reg, string, 0, 0, 0);
	regfree(&reg);
	
	return (result == 0) ? YES : NO;
}

- (BOOL)matchesFeaturePattern: (NSString *)featurePattern {
	NSMutableString *string = [NSMutableString stringWithString: featurePattern];

	[string replaceOccurrencesOfString:@"<*" withString:@"<[a-zA-Z]*"
							   options:0 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:@"*>" withString:@"[a-zA-Z]*>"
							   options:0 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:@">*<" withString:@">.+<"
							   options:0 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:@"*<" withString:@".+<"
							   options:0 range:NSMakeRange(0, [string length])];

	[string replaceOccurrencesOfString:@">*" withString:@">.+"
							   options:0 range:NSMakeRange(0, [string length])];

	return [self matches: string];
}
/*

if ([[file substringWithRange:NSMakeRange(0, 1)] isEqualToString:@"."]) {
    return NO;
}
if ([[entity substringWithRange:NSMakeRange(entity.length-2, 2)] isEqualToString:@"-0"]) {
    return NO;
}
*/

#if 0

// these seem to fail for some cases, e.g. the string "." as argument
- (BOOL)startsWith: (NSString *)startString {
	return [self matches: [NSString stringWithFormat: @"^%@", startString]];
}

- (BOOL)endsWith: (NSString *)endString {
	return [self matches: [NSString stringWithFormat: @"%@$", endString]];
}
#else

- (BOOL)startsWith: (NSString *)startString {
    if (self.length >= startString.length) {
        return [[self substringWithRange:NSMakeRange(0, startString.length)] isEqualToString:startString];
    }
    return NO;
}

- (BOOL)endsWith: (NSString *)endString {
    if (self.length >= endString.length) {
        return [[self substringWithRange:NSMakeRange(self.length-endString.length, endString.length)] isEqualToString:endString];
    }
    return NO;
}
#endif

- (BOOL)contains: (NSString *)substring {
	return ([self rangeOfString:substring].location != NSNotFound);
}

@end
