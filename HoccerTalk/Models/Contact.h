//
//  Contact.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface Contact : NSManagedObject

@property (nonatomic, retain) NSData*       avatar;
@property (nonatomic, retain) NSDate*       lastMessageTime;
@property (nonatomic, retain) NSString*     nickName;
@property (nonatomic, retain) NSString*     currentTimeSection;

@property (nonatomic, retain) NSMutableSet* messages;

@property (readonly, retain) UIImage* avatarImage;

- (NSString*) sectionTitleForMessageTime: (NSDate*) date;

@end
