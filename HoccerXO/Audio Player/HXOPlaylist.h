//
//  HXOPlaylist.h
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HXOPlaylistDelegate.h"

@class Attachment;

@protocol HXOPlaylist <NSObject>

- (NSUInteger) count;
- (Attachment *) attachmentAtIndex:(NSUInteger)index;
- (NSUInteger) indexOfAttachment:(Attachment *)attachment;

@property (nonatomic, weak) id<HXOPlaylistDelegate> delegate;

@end
