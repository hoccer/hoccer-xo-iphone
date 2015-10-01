//
//  Preview.h
//  HoccerXO
//
//  Created by pavel on 01.10.15.
//  Copyright © 2015 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Attachment;

NS_ASSUME_NONNULL_BEGIN

@interface Preview : NSManagedObject

+ (NSString*) entityName;

@end

NS_ASSUME_NONNULL_END

#import "Preview+CoreDataProperties.h"
