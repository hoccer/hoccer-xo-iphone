//
//  CollectionItem.h
//  HoccerXO
//
//  Created by Guido Lorenz on 03.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOModel.h"

@class Attachment;
@class Collection;

@interface CollectionItem : HXOModel

@property (nonatomic, retain) Attachment *attachment;
@property (nonatomic, retain) Collection *collection;
@property (nonatomic, assign) int        index;

@end
