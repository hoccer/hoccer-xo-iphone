//
//  HXOAudioAttachmentDataSourcePlaylist.h
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AudioAttachmentDataSource.h"
#import "HXOPlaylist.h"

@interface HXOAudioAttachmentDataSourcePlaylist : NSObject <HXOPlaylist, AudioAttachmentDataSourceDelegate>

- (id) initWithDataSource:(AudioAttachmentDataSource *)dataSource;

@property (nonatomic, weak) id<HXOPlaylistDelegate> delegate;

@end
