//
//  VcardWriter.h
//  Hoccer
//
//  Created by Robert Palmer on 06.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface VcardWriter : NSObject {
	NSMutableString  *vcardString;
}

- (void)writeHeader;
- (void)writeFooter;
- (void)writeFormattedName: (NSString *)name;
- (void)writeOrgaization: (NSString *)organization;
- (void)writeProperty: (NSString *)propertyName 
				value: (NSString *)valueName
			paramater: (NSArray *)parameter;

- (NSString *)vcardRepresentation;  




@end
