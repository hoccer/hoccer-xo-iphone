//
//  Collection.h
//  HoccerXO
//
//  Created by Guido Lorenz on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOModel.h"

@interface Collection : HXOModel

@property (nonatomic, retain) NSOrderedSet *attachments;

@end

@interface Collection (CoreDataGeneratedAccessors)

- (void)addAttachmentsObject:(NSManagedObject *)value;
- (void)removeAttachmentsObject:(NSManagedObject *)value;
- (void)addAttachments:(NSSet *)values;
- (void)removeAttachments:(NSSet *)values;

@end
