//
//  HXOPlaylistDelegate.h
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol HXOPlaylist;

@protocol HXOPlaylistDelegate <NSObject>

- (void) playlistDidChange:(id<HXOPlaylist>)playlist;
- (void) playlist:(id<HXOPlaylist>)playlist didRemoveAttachmentAtIndex:(NSUInteger)index;

@end
