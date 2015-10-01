//
//  Preview+CoreDataProperties.h
//  HoccerXO
//
//  Created by pavel on 01.10.15.
//  Copyright © 2015 Hoccer GmbH. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Preview.h"

NS_ASSUME_NONNULL_BEGIN

@interface Preview (CoreDataProperties)

@property (nullable, nonatomic, retain) NSData *imageData;
@property (nullable, nonatomic, retain) Attachment *attachment;

@end

NS_ASSUME_NONNULL_END
