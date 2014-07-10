//
//  HXOArrayPlaylist.h
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HXOPlaylist.h"

@interface HXOArrayPlaylist : NSObject <HXOPlaylist>

- (id) initWithArray:(NSArray *)array;

@property (nonatomic, weak) id<HXOPlaylistDelegate> delegate;

@end
