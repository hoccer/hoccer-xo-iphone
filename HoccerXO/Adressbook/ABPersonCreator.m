//
//  ABPersonCreator.m
//  Hoccer
//
//  Created by Robert Palmer on 12.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "ABPersonCreator.h"
#import "VcardParser.h"

@interface ABPersonCreator (Private)

- (CFStringRef)labelFromAttributes: (NSArray *)attributes;
- (CFDictionaryRef)createDirectoryFromAddressString: (NSString *)address;

@end




@implementation ABPersonCreator

@synthesize person;

- (id) initWithVcardString: (NSString *)vcard
{
	self = [super init];
	if (self != nil) {
		person = ABPersonCreate();
		
		VcardParser *parser = [[VcardParser alloc] initWithString:vcard];
		parser.delegate = self;
		
		[parser parse];
	}
	return self;
}

- (void) dealloc
{
	CFRelease(person);
}


#pragma mark -
#pragma mark VcardParserDelegate Methods


- (void)parser: (VcardParser*)parser didFoundFormattedName: (NSString *)name
{
	NSArray *splittedName = [name componentsSeparatedByString:@" "];
	
	CFErrorRef error;
	if([splittedName count] < 1)
		return;
	
	ABRecordSetValue(person, kABPersonFirstNameProperty, 
					 (__bridge CFTypeRef)([splittedName objectAtIndex:0]), &error);
	
	if ([splittedName count] > 1) {
		ABRecordSetValue(person, kABPersonLastNameProperty, 
						 (__bridge CFTypeRef)([splittedName objectAtIndex:1]), &error);
	}
}

- (void)parser: (VcardParser*)parser didFoundOrganization: (NSString *)name
{	
	CFErrorRef error;
	
	ABRecordSetValue(person, kABPersonOrganizationProperty, 
					 (__bridge CFTypeRef)(name), &error);
}


- (void)parser: (VcardParser*)parser didFoundPhoneNumber: (NSString*)number 
										  withAttributes: (NSArray *)attributes
{
	ABMultiValueRef currentPhoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
	CFErrorRef errorRef;

	ABMutableMultiValueRef numbers = NULL;
	if (currentPhoneNumbers == NULL) {
		numbers= ABMultiValueCreateMutable(kABMultiStringPropertyType);
	} else {
		numbers = ABMultiValueCreateMutableCopy(currentPhoneNumbers);
	}

	
	ABMultiValueAddValueAndLabel(numbers, (__bridge CFTypeRef)(number), [self labelFromAttributes: attributes], NULL);
	ABRecordSetValue(person, kABPersonPhoneProperty, numbers, &errorRef);
	
	CFRelease(numbers);
	
	if (currentPhoneNumbers != NULL)
		CFRelease(currentPhoneNumbers);
}


- (void)parser: (VcardParser*)parser didFoundEmail: (NSString*)email 
									withAttributes: (NSArray *)attributes 
{
	ABMultiValueRef currentEmaiAddresses = ABRecordCopyValue(person, kABPersonEmailProperty);
	CFErrorRef errorRef;

	ABMutableMultiValueRef emails = NULL;
	if (currentEmaiAddresses == NULL) {
		emails = ABMultiValueCreateMutable(kABMultiStringPropertyType);
	} else {
		emails = ABMultiValueCreateMutableCopy(currentEmaiAddresses);
	}
	
	ABMultiValueAddValueAndLabel(emails, (__bridge CFTypeRef)(email), [self labelFromAttributes: attributes], NULL);
	ABRecordSetValue(person, kABPersonEmailProperty, emails, &errorRef);

	CFRelease(emails);
	
	if (currentEmaiAddresses != NULL)
		CFRelease(currentEmaiAddresses);
}


- (void)parser: (VcardParser*)parser didFoundAddress: (NSString*)address 
									  withAttributes: (NSArray *)attributes
{
	ABMultiValueRef currentMultiValue = ABRecordCopyValue(person, kABPersonAddressProperty);
	CFErrorRef errorRef;
	
	ABMutableMultiValueRef addresses = NULL;
	if (currentMultiValue == NULL) {
		addresses = ABMultiValueCreateMutable(kABMultiStringPropertyType);
	} else {
		addresses = ABMultiValueCreateMutableCopy(currentMultiValue);
	}
	
	CFDictionaryRef addressDict = [self createDirectoryFromAddressString: address];
	ABMultiValueAddValueAndLabel(addresses, addressDict,
								 [self labelFromAttributes: attributes], NULL);
								 	
	ABRecordSetValue(person, kABPersonAddressProperty, addresses, &errorRef);
	
	CFRelease(addresses);
	if (currentMultiValue != NULL)
		CFRelease(currentMultiValue);
}



#pragma mark -
#pragma mark Private Methods

- (CFStringRef)labelFromAttributes: (NSArray *)theAttributes {

	NSMutableArray *attributes = [NSMutableArray arrayWithCapacity:[theAttributes count]];
	for (NSString *attribute in theAttributes) {
		[attributes addObject:[attribute uppercaseString]];
	}
	
	if([attributes isEqualToArray: [NSArray arrayWithObjects:@"WORK", nil]])
		return kABWorkLabel;
	
	if ([attributes isEqualToArray: [NSArray arrayWithObjects:@"HOME", nil]])
		 return kABHomeLabel;
	
	if  ([attributes isEqualToArray:[NSArray arrayWithObjects:@"OTHER", nil]])
		return kABOtherLabel;
	
	if([attributes isEqualToArray: [NSArray arrayWithObjects:@"MOBILE", nil]])
		return kABPersonPhoneMobileLabel;

	if ([attributes isEqualToArray: [NSArray arrayWithObjects:@"HOME", @"FAX", nil]])
		return kABPersonPhoneHomeFAXLabel;
	
	if ([attributes isEqualToArray:[NSArray arrayWithObjects:@"WORK", @"FAX", nil]])
		return kABPersonPhoneWorkFAXLabel;
	
	if ([attributes isEqualToArray: [NSArray arrayWithObjects:@"PAGER", nil]])
		return kABPersonPhonePagerLabel;
	
	return kABOtherLabel;
}


- (CFDictionaryRef)createDirectoryFromAddressString: (NSString *)address {
	
	NSArray *addressParts = [address componentsSeparatedByString:@";"];
	if (!addressParts)
		return nil;
	
	CFStringRef keys[5];
	CFStringRef values[5];
	keys[0]      = kABPersonAddressStreetKey;
	keys[1]      = kABPersonAddressCityKey;
	keys[2]      = kABPersonAddressStateKey;
	keys[3]      = kABPersonAddressZIPKey;
	keys[4]      = kABPersonAddressCountryKey;

	values[0]    = (__bridge CFStringRef) [addressParts objectAtIndex:0];
	
	// for (int
	
	
	if ([addressParts count] > 1) {
		values[1]  = (__bridge CFStringRef) [addressParts objectAtIndex:1];
	}
	if ([addressParts count] > 2) {
		values[2]  = (__bridge CFStringRef) [addressParts objectAtIndex:2];
	}
	if ([addressParts count] > 3) {
		values[3]  = (__bridge CFStringRef) [addressParts objectAtIndex:3];
	}
	if ([addressParts count] > 4) {
		values[4]  = (__bridge CFStringRef) [addressParts objectAtIndex:4];
	}
		
	NSInteger items = [addressParts count] < 5 ? [addressParts count] : 5;
	CFDictionaryRef aDict = CFDictionaryCreate(NULL,
											   (void *)keys,
											   (void *)values,
											   items,
											   &kCFCopyStringDictionaryKeyCallBacks,
											   &kCFTypeDictionaryValueCallBacks);
	return aDict;	
}


@end
