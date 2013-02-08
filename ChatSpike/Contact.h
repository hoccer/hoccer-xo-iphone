//
//  Contact.h
//  ChatSpike
//
//  Created by David Siegel on 07.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface Contact : NSManagedObject
{

}

@property (nonatomic, retain) NSString * nickName;
@property (nonatomic, retain) NSString * avatarURL;
@property (nonatomic, retain) NSMutableSet * messages;

@end
