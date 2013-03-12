//
//  Attachment.h
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Message;

@interface Attachment : NSManagedObject

@property (nonatomic, retain) NSString * filePath;
@property (nonatomic, retain) Message *message;

@end
