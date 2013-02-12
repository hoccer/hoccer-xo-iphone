//
//  Message.h
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "Contact.h"

@interface Message : NSManagedObject

@property (nonatomic, retain) NSString* text;
@property (nonatomic, retain) NSDate*   timeStamp;
@property (nonatomic)         BOOL      isOutgoing;

@property (nonatomic, retain) Contact*  contact;

@end
