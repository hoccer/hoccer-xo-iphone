//
//  HXOAudioPlayer.h
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

#import "HXOPlaylist.h"
#import "HXOPlaylistDelegate.h"

@class Attachment;

typedef NS_ENUM (NSUInteger, HXOAudioPlayerRepeatState) {
    HXOAudioPlayerRepeatStateOff,
    HXOAudioPlayerRepeatStateOne,
    HXOAudioPlayerRepeatStateAll
};

@interface HXOAudioPlayer : NSObject <AVAudioPlayerDelegate, HXOPlaylistDelegate>

+ (HXOAudioPlayer *) sharedInstance;

- (BOOL) playWithPlaylist:(id<HXOPlaylist>)playlist atTrackNumber:(NSUInteger)trackNumber;
- (BOOL) updatePlaylist:(id<HXOPlaylist>)playlist withStartingTrackNumber:(NSUInteger)trackNumber;
- (BOOL) play;
- (void) pause;
- (void) togglePlayPause;

- (void) skipBack;
- (void) skipForward;

- (void) toggleShuffle;
- (void) toggleRepeat;

@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) BOOL isShuffled;
@property (nonatomic, readonly) HXOAudioPlayerRepeatState repeatState;
@property (nonatomic, readonly) Attachment * attachment;
@property (nonatomic, readonly) NSUInteger currentTrackNumber;
@property (nonatomic, readonly) NSUInteger playlistLength;
@property (nonatomic, readonly) NSTimeInterval duration;
@property NSTimeInterval currentTime;

@end
