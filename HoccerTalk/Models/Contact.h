//
//  Contact.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface Contact : NSManagedObject


@property (nonatomic, strong) NSData*       avatar;
@property (nonatomic, strong) NSString*     clientId;
@property (nonatomic, strong) NSDate*       latestMessageTime;
@property (nonatomic, strong) NSString*     nickName;
@property (nonatomic, strong) NSString*     currentTimeSection;
@property (nonatomic, strong) NSArray*      unreadMessages;
@property (nonatomic, strong) NSArray*      latestMessage;

@property (nonatomic, strong) NSMutableSet* messages;

@property (readonly) UIImage* avatarImage;

- (NSString*) sectionTitleForMessageTime: (NSDate*) date;

@end
