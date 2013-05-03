//
//  VcardParserDeleegate.h
//  Hoccer
//
//  Created by Robert Palmer on 12.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//


@class VcardParser;

@protocol VcardParserDelegate <NSObject>

@optional
- (void)parser: (VcardParser*)parser didFindFormattedName: (NSString *)name;
- (void)parser: (VcardParser*)parser didFindOrganization: (NSString *)name;

- (void)parser: (VcardParser*)parser didFindPhoneNumber: (NSString*)name 
										  withAttributes: (NSArray *)attributes;

- (void)parser: (VcardParser*)parser didFindEmail: (NSString*)name 
									withAttributes: (NSArray *)attributes;

- (void)parser: (VcardParser*)parser didFindAddress: (NSString*)name 
									  withAttributes: (NSArray *)attributes;



@end

