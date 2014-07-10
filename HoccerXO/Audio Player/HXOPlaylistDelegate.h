//
//  HXOPlaylistDelegate.h
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;
@protocol HXOPlaylist;

@protocol HXOPlaylistDelegate <NSObject>

- (void) playlist:(id<HXOPlaylist>)playlist didRemoveAttachment:(Attachment *)attachment atIndex:(NSUInteger)index;

@end
