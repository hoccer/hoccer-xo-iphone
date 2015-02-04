//
//  HXOAudioAttachmentDataSourcePlaylist.h
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MediaAttachmentDataSource.h"
#import "HXOPlaylist.h"

@interface HXOAudioAttachmentDataSourcePlaylist : NSObject <HXOPlaylist, MediaAttachmentDataSourceDelegate>

- (id) initWithDataSource:(MediaAttachmentDataSource *)dataSource;

@property (nonatomic, weak) id<HXOPlaylistDelegate> delegate;

@end
