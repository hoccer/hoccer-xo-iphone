//
//  ABPersonVCardCreator.m
//  Hoccer
//
//  Created by Robert Palmer on 06.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "ABPersonVCardCreator.h"
#import "NSData+Base64.h"

#import <AddressBook/AddressBook.h>

@interface ABPersonVCardCreator (Private) 
- (void)generateVcard; 

- (NSString *)stringPropertyWithId: (ABPropertyID) propertyId;

- (NSString *)nameString;
- (void)createMultiValueWithID: (ABPropertyID)propertyID toVcardProperty: (NSString *)name;
- (void)createAddress;
- (NSString *)createAddressLineFromDictonary: (CFDictionaryRef) address;
- (NSArray *)propertiesFromLabel: (CFStringRef)label;

@end



@implementation ABPersonVCardCreator

+ (NSData* )vcardWithABPerson: (ABRecordRef)record
{
	ABPersonVCardCreator *creator = [[ABPersonVCardCreator alloc]
									 initWithPerson:record];
	
	return [creator vcard];
}

- (id)initWithPerson: (ABRecordRef)record
{
	self = [super init];
	if (self != nil) {
		writer = [[VcardWriter alloc] init];
		
		person = record;
		CFRetain(person);
		
		[self generateVcard];
	}
	return self;
}

- (NSData *)vcard
{
	return [[writer vcardRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)vcardString {
	return [writer vcardRepresentation];
}


- (void) dealloc
{
	CFRelease(person);	
}


- (void)generateVcard 
{
	[writer writeHeader];
	[writer writeFormattedName: [self nameString]];
	[writer writeOrganization: [self organization]];
	
	[self createMultiValueWithID: kABPersonPhoneProperty toVcardProperty: @"TEL"];
	[self createMultiValueWithID: kABPersonEmailProperty toVcardProperty: @"EMAIL"];
	[self createAddress];
	[self createPhoto];

	[writer writeFooter];
    // NSLog(@"generateVcard=%@",[self vcardString]);
}


- (NSString *)organization
{
	return [self stringPropertyWithId:kABPersonOrganizationProperty];
}

- (NSString *)nameString
{
	NSString *firstName = [self stringPropertyWithId: kABPersonFirstNameProperty];
	NSString *lastName = [self stringPropertyWithId: kABPersonLastNameProperty];
	
	if (lastName == nil && firstName == nil) {
		return nil;
	}
	
	if (lastName != nil && firstName == nil) {
		return lastName;
	}
	
	if (lastName == nil && firstName != nil) {
		return firstName;
	}
	
	return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
}

- (NSString *)previewName 
{
	NSString *name = [self nameString];
	if (name != nil)
		return name;
	
	return [self organization];
}



- (void)createMultiValueWithID: (ABPropertyID)propertyID toVcardProperty: (NSString *)name
{
	ABMultiValueRef multi = ABRecordCopyValue(person, propertyID); 
	
	if (multi == NULL) {
		return;
	}
	
	CFStringRef value, valueLabel;
	for (CFIndex i = 0; i < ABMultiValueGetCount(multi); i++) {
		value	   = ABMultiValueCopyValueAtIndex(multi, i);
		valueLabel = ABMultiValueCopyLabelAtIndex(multi, i);
		
		[writer writeProperty:name value:(__bridge NSString *)value paramater:
					[self propertiesFromLabel:valueLabel]];		
		
		if (value != NULL) CFRelease(value);
		if (valueLabel != NULL) CFRelease(valueLabel);
	}
	
	CFRelease(multi);
}

- (void)createPhoto
{
    if (ABPersonHasImageData(person)) {
        NSData * myImageData = CFBridgingRelease(ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail));
        NSString * myImageString = [myImageData asBase64EncodedString];
        [writer writePhoto:myImageString];
    }
}

- (void)createAddress
{
	ABMultiValueRef multi = ABRecordCopyValue(person, kABPersonAddressProperty);
	if (multi == NULL) return;

	CFStringRef label;
	CFDictionaryRef address;
	for (CFIndex i = 0; i < ABMultiValueGetCount(multi); i++) {
		
        address = ABMultiValueCopyValueAtIndex(multi, i);
		label = ABMultiValueCopyLabelAtIndex(multi, i);
		
		[self createAddressLineFromDictonary: address];
		[writer writeProperty: @"ADR" value: [self createAddressLineFromDictonary: address]
					paramater:[[self propertiesFromLabel: label] arrayByAddingObject: @"POSTAL"]];
		
		if (label != NULL) CFRelease(label);
		if (address != NULL) CFRelease(address);
	}
		
    CFRelease(multi);
}


- (NSString *)createAddressLineFromDictonary: (CFDictionaryRef) address
{
	CFIndex size = CFDictionaryGetCount(address);
	
	CFStringRef values[size];
	CFDictionaryGetKeysAndValues(address, NULL, (void *)&values);
	
	NSMutableString *addressLine = [NSMutableString stringWithString: (__bridge NSString *)values[0]];
	for (CFIndex i = 1; i < size; i++) {
		[addressLine appendFormat: @";%@", (__bridge NSString *)values[i]];
	}
		
	return addressLine;
}



#pragma mark -
#pragma mark Private Methods


- (NSString *)stringPropertyWithId: (ABPropertyID) propertyId
{
	CFStringRef propertyValue = (CFStringRef) ABRecordCopyValue(person, propertyId);
	if (propertyValue == NULL)
		return nil;
	
	NSString *propertyString = [NSString stringWithString: (__bridge NSString *)propertyValue];
	
	CFRelease(propertyValue);
	return propertyString;
}



- (NSArray *)propertiesFromLabel: (CFStringRef)label
{
	if (label == nil) {
		return [NSArray arrayWithObjects:@"OTHER", nil];
	}	
	
	if (CFStringCompare(label, kABWorkLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo)
		return [NSArray arrayWithObjects:@"WORK", nil];
	
	if (CFStringCompare(label, kABHomeLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo)
		return [NSArray arrayWithObjects:@"HOME", nil];

	if (CFStringCompare(label, kABOtherLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo)
		return [NSArray arrayWithObjects:@"OTHER", nil];
	
	if (CFStringCompare(label, kABPersonPhoneMainLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo)
			return [NSArray arrayWithObjects:@"HOME", nil];
	
	if (CFStringCompare(label, kABPersonPhoneMobileLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo) 
		return [NSArray arrayWithObjects:@"MOBILE", nil];
	
	if (CFStringCompare(label, kABPersonPhoneIPhoneLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo) 
		return [NSArray arrayWithObjects:@"MOBILE", nil];
	
	if (CFStringCompare(label, kABPersonPhoneHomeFAXLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo) 
		return [NSArray arrayWithObjects:@"HOME", @"FAX", nil];
	
	if (CFStringCompare(label, kABPersonPhoneWorkFAXLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo) 
		return [NSArray arrayWithObjects:@"WORK", @"FAX", nil];
	
	if (CFStringCompare(label, kABPersonPhonePagerLabel, kCFCompareCaseInsensitive) ==  kCFCompareEqualTo) 
		return [NSArray arrayWithObjects:@"PAGER", nil];
	
	return  [NSArray arrayWithObjects:[NSString stringWithFormat:@"X-%@", label], nil];
}

@end
