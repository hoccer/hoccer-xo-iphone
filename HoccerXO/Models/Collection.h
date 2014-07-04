//
//  Collection.h
//  HoccerXO
//
//  Created by Guido Lorenz on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOModel.h"

@interface Collection : HXOModel

@property (nonatomic, retain) NSSet *items;
@property (nonatomic, retain) NSString *name;

- (void) appendAttachments:(NSArray *)attachments;
- (void) moveAttachmentAtIndex:(NSUInteger)sourceIndex toIndex:(NSUInteger)destinationIndex;
- (void) removeItemAtIndex:(NSUInteger)itemIndex;

@end
