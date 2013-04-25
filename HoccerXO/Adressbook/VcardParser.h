//
//  VcardParser.h
//  Hoccer
//
//  Created by Robert Palmer on 08.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VcardParserDelegate.h"


@interface VcardParser : NSObject {
	NSArray *vcardLines;
	
	id <VcardParserDelegate> delegate;
}

@property (nonatomic, retain) id delegate;

- (id)initWithString: (NSString *)vcard;
- (BOOL)isValidVcard;

- (void)parse;

@end
