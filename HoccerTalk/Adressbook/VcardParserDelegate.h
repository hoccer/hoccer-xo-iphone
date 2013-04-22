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
- (void)parser: (VcardParser*)parser didFoundFormattedName: (NSString *)name;
- (void)parser: (VcardParser*)parser didFoundOrganization: (NSString *)name;

- (void)parser: (VcardParser*)parser didFoundPhoneNumber: (NSString*)name 
										  withAttributes: (NSArray *)attributes;

- (void)parser: (VcardParser*)parser didFoundEmail: (NSString*)name 
									withAttributes: (NSArray *)attributes;

- (void)parser: (VcardParser*)parser didFoundAddress: (NSString*)name 
									  withAttributes: (NSArray *)attributes;



@end

