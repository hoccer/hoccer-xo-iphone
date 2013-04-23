//
//  ACPerson.h
//  Hoccer
//
//  Created by Robert Palmer on 22.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ACAddressBookPerson : NSObject {
	ABRecordID personId;
	ABRecordRef personRecordRef;
}

- (id)initWithId: (ABRecordID)recordId;
- (NSString *)name;


@end
