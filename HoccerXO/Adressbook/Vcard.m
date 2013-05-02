//
//  Vcard.m
//  HoccerXO
//
//  Created by Pavel on 02.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "Vcard.h"
#import "NSString+StringWithData.h"

@implementation VcardPreview
@synthesize name,otherInfo,personImage,company;
@end

@implementation Vcard

{
    ABPersonCreator * personCreator;
}

@synthesize person = _person;


- (id) initWithVcardString: (NSString *)theVcardString
{
	self = [super init];
	if (self != nil) {
        personCreator =[[ABPersonCreator alloc ]initWithVcardString:theVcardString];
        NSLog(@"initWithVcardString: personCreator = %@", personCreator);
        _person = personCreator.person;
        NSLog(@"initWithVcardString: person = %@", _person);
	}
	return self;
}

- (id) initWithVcardURL: (NSURL *)theVcardURL
{
	self = [super init];
	if (self != nil) {
        NSData * myVcardData = [NSData dataWithContentsOfURL:theVcardURL];
        NSLog(@"initWithVcardURL: %@, contentSize = %d", theVcardURL, myVcardData.length);
        NSString *myVcardString = [NSString stringWithData:myVcardData usingEncoding:NSUTF8StringEncoding];
        return [self initWithVcardString:myVcardString];
 	}
	return self;
}

- (NSString *)nameString {
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

- (NSString *)organization {
	return [self stringPropertyWithId:kABPersonOrganizationProperty];
}

- (NSString *)previewName {
	NSString *name = [self nameString];
	if (name != nil)
		return name;
	
	return [self organization];
}

- (NSString *)stringPropertyWithId: (ABPropertyID) propertyId {
	CFStringRef propertyValue = (CFStringRef) ABRecordCopyValue(_person, propertyId);
	if (propertyValue == NULL)
		return nil;
	
	NSString *propertyString = [NSString stringWithString: (__bridge NSString *)propertyValue];
	
	CFRelease(propertyValue);
	return propertyString;
}

- (UIImage *) previewImage {
    return [self previewImageWithScale:0];
}

- (UIImage *) previewImageWithScale:(CGFloat) myScale {
    UIView * myPreview = [self preview];
    return [Vcard imageFromView:myPreview withScale:myScale];
}

// If scale is 0, iscreen scale is used to create the bounds
+ (UIImage *)imageFromView:(UIView*)view withScale:(CGFloat)scale {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, scale);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return copied;
}

- (UIView *)preview {
    if (self.person != nil) {
        
        [[[NSBundle mainBundle] loadNibNamed:@"VcardPreview" owner:self options:nil] objectAtIndex:0];
        
        NSLog(@"previewName = %@", [self previewName]);
        NSLog(@"self.view.name = %@", self.view.name);
        NSLog(@"self.view.name.text = %@", self.view.name.text);
        self.view.name.text = [self previewName];
        NSLog(@"self.view.name.text = %@", self.view.name.text);
        
        NSLog(@"organization = %@", [self organization]);
        self.view.company.text = [self organization];
        
        CFTypeRef imageData = ABPersonCopyImageData(_person);
        if (imageData != NULL) {
            self.view.personImage.image = [UIImage imageWithData:(NSData *)CFBridgingRelease(imageData)];
        }
        
        NSMutableArray *telephone = [[NSMutableArray alloc] initWithCapacity:2];
        ABMultiValueRef phones = ABRecordCopyValue(_person, kABPersonPhoneProperty);
        if (phones != nil) {
            
            for(CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
                
                CFStringRef locLabelRef = ABMultiValueCopyLabelAtIndex(phones, i);
                CFStringRef phoneNumberRef = ABMultiValueCopyValueAtIndex(phones, i);
                CFTypeRef phoneLabelRef = ABAddressBookCopyLocalizedLabel(locLabelRef);
                
                NSString *phoneNumber = (NSString *)CFBridgingRelease(phoneNumberRef);
                NSString *phoneLabel = (NSString *)CFBridgingRelease(phoneLabelRef);
                
                if ([phoneLabel isEqualToString:@""]){
                    phoneLabel = @"phone";
                }
                
                NSString *toPhoneArray = [NSString stringWithFormat:@"%@:  %@", phoneLabel, phoneNumber];
                [telephone addObject:toPhoneArray];
                
                if (locLabelRef != NULL) CFRelease(locLabelRef);
            }
            
            if (phones != NULL) CFRelease(phones);
        }
        
        NSMutableArray *emails = [[NSMutableArray alloc] initWithCapacity:2];
        ABMultiValueRef email = ABRecordCopyValue(_person, kABPersonEmailProperty);
        if (email != nil) {
            
            for(CFIndex i = 0; i < ABMultiValueGetCount(email); i++) {
                
                CFStringRef locLabel = ABMultiValueCopyLabelAtIndex(email, i);
                CFStringRef emailRef = ABMultiValueCopyValueAtIndex(email, i);
                CFTypeRef emailLabelRef = ABAddressBookCopyLocalizedLabel(locLabel);
                
                NSString *emailAdress = (NSString *)CFBridgingRelease(emailRef);
                NSString *emailLabel = (NSString *)CFBridgingRelease(emailLabelRef);
                
                if ([emailLabel isEqualToString:@""]) {
                    emailLabel = @"email";
                }
                
                NSString *toEmailArray = [NSString stringWithFormat:@"%@:  %@", emailLabel, emailAdress];
                [emails addObject:toEmailArray];
                
                if (locLabel != NULL){
                    CFRelease(locLabel);
                }
            }
            
            if (email != NULL) CFRelease(email);
        }
        
        NSString *otherInfo = @"";
        for (NSString *number in telephone){
            otherInfo = [otherInfo stringByAppendingFormat:@"%@\n",number];
        }
        
        for (NSString *address in emails){
            otherInfo = [otherInfo stringByAppendingFormat:@"%@\n",address];
        }
        NSLog(@"otherInfo = %@", otherInfo);
        
        // CGRect myRect = self.view.otherInfo.frame;
        
        self.view.otherInfo.text = otherInfo;
        
        CGSize theLabelSize = [self calcLabelSize:otherInfo withFont:[UIFont systemFontOfSize:15] maxSize:CGSizeMake(282, 640)];
        
        self.view.otherInfo.frame = CGRectMake(12, 56, theLabelSize.width, theLabelSize.height);
        
        CGRect myFrame = self.view.frame;
        myFrame.size.height = self.view.otherInfo.frame.origin.y + self.view.otherInfo.frame.size.height + 5;
        self.view.frame = myFrame;
        
        return self.view;

    }
    return nil;
}

-(CGSize) calcLabelSize:(NSString *)string withFont:(UIFont *)font maxSize:(CGSize)maxSize {
    return [string
            sizeWithFont:font
            constrainedToSize:maxSize
            lineBreakMode:NSLineBreakByWordWrapping];
    
}


@end
