//
//  ABPersonVCardCreator.h
//  Hoccer
//
//  Created by Robert Palmer on 06.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

#import "VcardWriter.h"

@interface ABPersonVCardCreator : NSObject {
	ABRecordRef person;

	VcardWriter *writer;
}

+ (NSData* )vcardWithABPerson: (ABRecordRef)record;

- (id)initWithPerson: (ABRecordRef)record;
- (NSData *)vcard;
- (NSString *)vcardString;

- (NSString *)nameString;
- (NSString *)organization;

- (NSString *)previewName;

@end
