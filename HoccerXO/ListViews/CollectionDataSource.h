//
//  ConversationDataSource.h
//  HoccerXO
//
//  Created by Guido Lorenz on 03.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MediaAttachmentDataSource.h"

@class Collection;

@interface CollectionDataSource : MediaAttachmentDataSource

- (id) initWithCollection:(Collection *)collection;

@end
