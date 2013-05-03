//
//  VcardParser.m
//  Hoccer
//
//  Created by Robert Palmer on 08.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "VcardParser.h"
#import "NSString+Regexp.h"

@interface VcardParser (Private) 

- (NSArray *)attributesFromString: (NSString *) string;

@end



@implementation VcardParser


@synthesize delegate;

- (id)initWithString: (NSString *)vcard
{
	self = [super init];
	if (self != nil) {
		vcardLines = [vcard componentsSeparatedByString:@"\r\n"];
	}
	return self;
}

- (void) dealloc
{
}

- (BOOL)isValidVcard
{
	if ([vcardLines count] < 2)
		return NO;
	
	return [[vcardLines objectAtIndex:0] isEqual: @"BEGIN:VCARD"] && 
				[[vcardLines objectAtIndex:1] isEqual: @"VERSION:3.0"] &&
				[[vcardLines lastObject] isEqual: @"END:VCARD"];
}

- (void)parse
{
	for (int i = 2; i < [vcardLines count]; i++) {
		if ([[vcardLines objectAtIndex:i] length] == 0) {
			return;
		}
		
		NSArray *propertyWithAttributesAndValue = [[vcardLines objectAtIndex:i] 
												   componentsSeparatedByString: @":"];
		
		if ([propertyWithAttributesAndValue count] < 2) {
			return;
		}
		
		NSString *propertyWithAttributes = [propertyWithAttributesAndValue objectAtIndex:0];
		NSArray *propertyAndAttributes = [propertyWithAttributes componentsSeparatedByString: @";"];
		
		NSString *attributes = nil;
		NSString *value = [propertyWithAttributesAndValue objectAtIndex:1];
		NSString *property = [propertyAndAttributes objectAtIndex:0];
		
		if ([propertyAndAttributes count] > 1) {
			attributes = [propertyAndAttributes objectAtIndex:1];
		}
		
		if ([property isEqual: @"FN"]) {
			[delegate parser: self didFindFormattedName: value];
		} else if ([property isEqual: @"TEL"]) {
			[delegate parser: self didFindPhoneNumber: value 
			  withAttributes: [self attributesFromString: attributes]];
		} else if ([property isEqual: @"EMAIL"]) {
			[delegate parser: self didFindEmail: value 
			  withAttributes: [self attributesFromString: attributes]];
		} else if ([property isEqual: @"ADR"]) {
			[delegate parser: self didFindAddress: value 
			  withAttributes: [self attributesFromString: attributes]];
		} else if ([property isEqual: @"ORG"]) {
			[delegate parser: self didFindOrganization: value];
		} else if ([property isEqual: @"PHOTO"]) {
			[delegate parser: self didFindPhoto: value
			  withAttributes: [self attributesFromString: attributes]];
		}
	}
}

- (NSArray *)attributesFromString: (NSString *) string
{
	if (!string)
		return nil;
	
	NSArray *attributs = nil;
	
	if ([string contains:@","]) {
		attributs = [string componentsSeparatedByString:@","];
	} else if ([string contains:@";"]) {
		attributs = [string componentsSeparatedByString:@";"];
	} else {
		attributs = [NSArray arrayWithObject: string];
	}		
	
	NSMutableArray *mutableAttributes = [NSMutableArray arrayWithArray:attributs];
	for (int i = 0; i < [attributs count]; i++) {
		if ([[mutableAttributes objectAtIndex:i] startsWith: @"TYPE="]) {
			NSString *attributString = [mutableAttributes objectAtIndex:i];
			
			[mutableAttributes replaceObjectAtIndex:i 
										 withObject: [attributString substringFromIndex:5]];
		}
	}
	
	return mutableAttributes;
}

@end
