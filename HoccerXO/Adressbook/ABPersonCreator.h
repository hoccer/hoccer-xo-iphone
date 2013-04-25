//
//  ABPersonCreator.h
//  Hoccer
//
//  Created by Robert Palmer on 12.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import "VcardParserDelegate.h"


@interface ABPersonCreator : NSObject <VcardParserDelegate> {
	ABRecordRef person;
}

@property (readonly) ABRecordRef person;

- (id) initWithVcardString: (NSString *)vcard;

@end
