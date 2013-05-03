//
//  VcardWriter.m
//  Hoccer
//
//  Created by Robert Palmer on 06.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "VcardWriter.h"


@implementation VcardWriter

- (id) init
{
	self = [super init];
	if (self != nil) {
		vcardString = [[NSMutableString alloc] init];
	}
	
	return self;
}


- (void)writeProperty: (NSString *)propertyName 
				value: (NSString *)value
			paramater: (NSArray *)parameter 
{
	if (value == nil)
		return;
	
	NSString *line = nil;
	
	if (!parameter) {
		line = [NSString stringWithFormat: @"%@:%@\r\n", propertyName,  value];
	} else {
		NSString *parameterString = [NSString stringWithFormat:  @"TYPE=%@", 
									[parameter componentsJoinedByString: @","]];
		
		line = [NSString stringWithFormat: @"%@;%@:%@\r\n",  propertyName, 
				parameterString, value];
	}
	[vcardString appendString: line];
}

- (void)writePhoto: (NSString *)b64String
{
    NSString * line = [NSString stringWithFormat: @"PHOTO;TYPE=JPEG;ENCODING=B:%@\r\n", b64String];
	[vcardString appendString: line];
}

- (void)writeFormattedName: (NSString *)name
{
	[self writeProperty:@"FN" value:name paramater:nil];
}

- (void)writeOrganization: (NSString *)organization
{
	[self writeProperty:@"ORG" value:organization paramater:nil];
	
}


- (void)writeHeader
{
	[vcardString appendString: @"BEGIN:VCARD\r\nVERSION:3.0\r\n"];
}

- (void)writeFooter
{
	[vcardString appendString: @"END:VCARD"];
}


- (void) dealloc
{
}



- (NSString *)vcardRepresentation 
{
	return vcardString;
}


@end
