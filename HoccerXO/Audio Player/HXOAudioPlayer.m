//
//  HXOAudioPlayer.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioPlayer.h"

#import <MediaPlayer/MediaPlayer.h>

#import "Attachment.h"
#import "AppDelegate.h"
#import "AttachmentInfo.h"
#import "NSArray+Shuffle.h"

@interface HXOAudioPlayer ()

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isShuffled;
@property (nonatomic, strong) Attachment * attachment;
@property (nonatomic, strong) AVAudioPlayer * player;
@property (nonatomic, strong) NSArray * playlist;
@property (nonatomic, strong) NSArray * playlistIndices;
@property (nonatomic, assign) NSUInteger playlistIndex;

@end


@implementation HXOAudioPlayer

#pragma mark - Singleton instantiation

+ (HXOAudioPlayer *) sharedInstance {
    static HXOAudioPlayer *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (id) init {
    self = [super init];
    
    if (self) {
        self.playlist = @[];
        self.playlistIndices = [NSMutableArray alloc];
        self.playlistIndex = 0;
        self.isShuffled = NO;
    }
    
    return self;
}

#pragma mark - Public interface

- (BOOL) playWithPlaylist: (NSArray *) playlist atIndex: (NSUInteger) index {
    self.playlist = playlist;
    [self createPlaylistIndices];

    return [self playAtIndex:index];
}

- (BOOL) play {
    return [self playAtIndex:self.playlistIndex];
}

- (void) pause {
    [self.player pause];
    self.isPlaying = NO;
}

- (void) togglePlayPause {
    if (self.isPlaying) {
        [self pause];
    } else {
        [self play];
    }
}

- (void) skipBack {
    if (self.currentTime > 3.0){
        self.currentTime = 0.0;
    } else {
        if (self.playlistIndex > 0) {
            [self playAtIndex:self.playlistIndex - 1];
        }
    }
}

- (void) skipForward {
    if (self.playlistIndex < self.playlist.count - 1) {
        [self playAtIndex:self.playlistIndex + 1];
    }
}

- (NSTimeInterval) currentTime {
    if (self.player) {
        return self.player.currentTime;
    } else {
        return 0.0;
    }
}

- (NSTimeInterval) duration {
    if (self.player) {
        return self.player.duration;
    } else {
        return 0.0;
    }
}

- (NSUInteger) playlistLength {
    return self.playlist.count;
}

- (NSUInteger) currentPlaylistTrackNumber {
    return (NSUInteger)[self.playlistIndices objectAtIndex: self.playlistIndex];
}


- (void) toggleShuffle {
    if (self.isShuffled) {
        self.isShuffled = YES;
    } else {
        self.isShuffled = NO;
    }

    [self createPlaylistIndices];
}

- (void) toggleRepeat {

}

#pragma mark - Private helpers

- (BOOL) playAtIndex: (NSUInteger) index {
    self.playlistIndex = index;
    
    if (index < self.playlist.count) {
        Attachment *attachment = [self.playlist objectAtIndex:index];
        return [self playAttachment:attachment];
    } else {
        return YES;
    }
}

- (BOOL) playAttachment: (Attachment *) attachment {
    self.attachment = attachment;
    
    if (self.player) {
        [AppDelegate setMusicAudioSession];
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        [[AppDelegate instance] becomeFirstResponder];
        
        [self.player play];
        self.isPlaying = YES;
    } else {
        self.isPlaying = NO;
    }
    
    return self.isPlaying;
}

- (void) stop {
    [self pause];
    self.attachment = nil;
}

- (void) setAttachment:(Attachment *)attachment {
    if (![_attachment isEqual:attachment]) {
        _attachment = attachment;

        if (attachment) {
            self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:attachment.contentURL error:nil];
            [self.player setDelegate:self];
        } else {
            self.player = nil;
        }
    }
    
    [self updateNowPlayingInfo];
}

- (void) setCurrentTime:(NSTimeInterval)currentTime {
    if (self.player) {
        self.player.currentTime = currentTime;
    }
}

- (void) updateNowPlayingInfo {
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    if (self.attachment) {
        AttachmentInfo *attachmentInfo = [[AttachmentInfo alloc] initWithAttachment:self.attachment];
        NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionary];
        
        if (attachmentInfo.audioTitle) {
            [nowPlayingInfo setValue:attachmentInfo.audioTitle forKey:MPMediaItemPropertyTitle];
        }

        if (attachmentInfo.audioArtist) {
            [nowPlayingInfo setValue:attachmentInfo.audioArtist forKey:MPMediaItemPropertyArtist];
        }

        if (attachmentInfo.audioAlbum) {
            [nowPlayingInfo setValue:attachmentInfo.audioAlbum forKey:MPMediaItemPropertyAlbumTitle];
        }

        [nowPlayingInfo setValue:[NSNumber numberWithDouble:attachmentInfo.audioDuration] forKey:MPMediaItemPropertyPlaybackDuration];

        infoCenter.nowPlayingInfo = nowPlayingInfo;
    } else {
        infoCenter.nowPlayingInfo = nil;
    }
}

- (void) createPlaylistIndices {
    NSUInteger current = 0;
    if ([self.playlistIndices count] > 0) {
        current = [self currentPlaylistTrackNumber];
    }
    
    NSMutableArray *indices = [[NSMutableArray alloc] initWithCapacity:[self.playlist count]];
    for (int i = 0; i < [self.playlist count]; i++) {
        [indices addObject:[NSNumber numberWithInt:i]];
    }

    self.playlistIndices = indices;
    if (self.isShuffled) {
        NSMutableArray *shuffledPlaylist = [[NSMutableArray alloc] initWithArray: [self.playlistIndices arrayByShuffling]];
        NSNumber *currentTrackNumber = [NSNumber numberWithInt:self.currentPlaylistTrackNumber];
        NSNumber *firstShuffledTrackNumber = [shuffledPlaylist firstObject];
        NSUInteger indexOfCurrentTrackNumber = [shuffledPlaylist indexOfObject:currentTrackNumber];
        [shuffledPlaylist insertObject:currentTrackNumber atIndex:0];
        [shuffledPlaylist insertObject:firstShuffledTrackNumber atIndex: indexOfCurrentTrackNumber];
        self.playlistIndex = 0;
        self.playlistIndices = shuffledPlaylist;
    } else {
        self.playlistIndex = current;
    }
}

#pragma mark - AVAudioPlayerDelegate methods

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) flag {
    [AppDelegate setDefaultAudioSession];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[AppDelegate instance] resignFirstResponder];

    if (self.playlistIndex < self.playlist.count - 1) {
        [self skipForward];
    } else {
        [self stop];
    }
}

- (void) audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self stop];
}

@end
