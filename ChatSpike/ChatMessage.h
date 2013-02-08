//
//  ChatMessage.h
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "Contact.h"

@interface ChatMessage : NSManagedObject
{
    
}

@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSDate * creationDate;
@property (nonatomic, retain) Contact * contact;

@end
