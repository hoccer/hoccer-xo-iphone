//
//  HXOAudioPlayer.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioPlayer.h"

#import <MediaPlayer/MediaPlayer.h>

#import "AppDelegate.h"
#import "Attachment.h"
#import "AttachmentInfo.h"
#import "HXOArrayPlaylist.h"
#import "NSMutableArray+Shuffle.h"

@interface HXOAudioPlayer ()

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL isShuffled;
@property (nonatomic, assign) HXOAudioPlayerRepeatState repeatState;
@property (nonatomic, strong) Attachment * attachment;
@property (nonatomic, strong) AVAudioPlayer * player;
@property (nonatomic, strong) id<HXOPlaylist> playlist;
@property (nonatomic, strong) NSArray * trackNumbers;
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
        self.playlist = [[HXOArrayPlaylist alloc] initWithArray:@[]];
        self.trackNumbers = @[];
        self.playlistIndex = 0;
        self.isShuffled = NO;
        self.repeatState = HXOAudioPlayerRepeatStateOff;
    }
    
    return self;
}

#pragma mark - Public interface

- (BOOL) playWithPlaylist:(id<HXOPlaylist>)playlist atTrackNumber:(NSUInteger)trackNumber {
    NSUInteger index = [self setPlaylist:playlist andGetIndexForTrackNumber:trackNumber];
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

- (void) stop {
    [self pause];
    [self playAttachment:nil];
}

- (void) skipBack {
    if (self.currentTime > 3.0){
        self.currentTime = 0.0;
    } else {
        if (self.playlistIndex > 0) {
            [self playAtIndex:self.playlistIndex - 1];
        } else {
            [self playAtIndex:[self.playlist count] - 1];
        }
    }
}

- (void) skipForward {
    if (self.playlistIndex < [self.playlist count] - 1) {
        [self playAtIndex:self.playlistIndex + 1];
    } else {
        [self playAtIndex:0];
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
    return [self.playlist count];
}

- (NSUInteger) currentTrackNumber {
    return [(NSNumber *)[self.trackNumbers objectAtIndex:self.playlistIndex] unsignedIntegerValue];
}


- (void) toggleShuffle {
    self.isShuffled = !self.isShuffled;
    NSUInteger index = [self orderTrackNumbersWithCurrentTrackNumber:self.currentTrackNumber];
    [self playAtIndex:index];
}

- (void) toggleRepeat {
    switch (self.repeatState) {
        case HXOAudioPlayerRepeatStateOff:
            self.repeatState = HXOAudioPlayerRepeatStateAll;
            break;
            
        case HXOAudioPlayerRepeatStateAll:
            self.repeatState = HXOAudioPlayerRepeatStateOne;
            break;

        case HXOAudioPlayerRepeatStateOne:
            self.repeatState = HXOAudioPlayerRepeatStateOff;
            break;
    }
}

#pragma mark - Private helpers

- (BOOL)updatePlaylist:(id<HXOPlaylist>)playlist withStartingTrackNumber:(NSUInteger)trackNumber {
    
    NSUInteger index = [self setPlaylist:playlist andGetIndexForTrackNumber:trackNumber];
    
    if ([self isPlaying]) {
        return [self playAtIndex:index];
    } else {
        NSAssert(index < [self.playlist count], @"playlist index out of bounds");
        self.playlistIndex = index;
        return YES;
    }
}

- (NSUInteger) setPlaylist:(id<HXOPlaylist>)playlist andGetIndexForTrackNumber: (NSUInteger) trackNumber {
    self.playlist = playlist;
    playlist.delegate = self;
    return [self orderTrackNumbersWithCurrentTrackNumber:trackNumber];
}

- (BOOL) playAtIndex: (NSUInteger) index {
    NSAssert(index < [self.playlist count], @"playlist index out of bounds");

    self.playlistIndex = index;
    
    Attachment *attachment = [self.playlist attachmentAtIndex:self.currentTrackNumber];
    return [self playAttachment:attachment];
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
    
    [self updateNowPlayingInfo];
    return self.isPlaying;
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
}

- (void) setCurrentTime:(NSTimeInterval)currentTime {
    if (self.player) {
        self.player.currentTime = currentTime;
    }
}

- (void) updateNowPlayingInfo {
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    if (self.attachment) {
        AttachmentInfo *attachmentInfo = [AttachmentInfo infoForAttachment:self.attachment];
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

        infoCenter.nowPlayingInfo = nowPlayingInfo;
    } else {
        infoCenter.nowPlayingInfo = nil;
    }
}

- (NSUInteger) orderTrackNumbersWithCurrentTrackNumber: (NSUInteger) trackNumber {
    NSMutableArray *orderedTrackNumbers = [[NSMutableArray alloc] initWithCapacity:[self.playlist count]];
    for (int i = 0; i < [self.playlist count]; i++) {
        [orderedTrackNumbers addObject:[NSNumber numberWithInt:i]];
    }

    if (self.isShuffled) {
        NSNumber *currentTrackNumber = [orderedTrackNumbers objectAtIndex:trackNumber];

        [orderedTrackNumbers shuffle];
        NSUInteger indexOfCurrentTrackNumber = [orderedTrackNumbers indexOfObject:currentTrackNumber];
        [orderedTrackNumbers exchangeObjectAtIndex:0 withObjectAtIndex:indexOfCurrentTrackNumber];

        self.trackNumbers = orderedTrackNumbers;
        return 0;
    } else {
        self.trackNumbers = orderedTrackNumbers;
        return trackNumber;
    }
}

#pragma mark - HXOPlaylistDelegate

- (void) playlistDidChange:(id<HXOPlaylist>)playlist {
    NSUInteger newTrackNumber = [playlist indexOfAttachment:self.attachment];
    [self updatePlaylist:self.playlist withStartingTrackNumber:newTrackNumber];
}

- (void) playlist:(id<HXOPlaylist>)playlist didRemoveAttachmentAtIndex:(NSUInteger)index {
    NSUInteger currentTrackNumber = [self currentTrackNumber];
    NSUInteger newTrackNumber = index < currentTrackNumber ? currentTrackNumber - 1 : currentTrackNumber;
    
    if (newTrackNumber < [self.playlist count]) {
        [self updatePlaylist:self.playlist withStartingTrackNumber:newTrackNumber];
    } else {
        [self stop];
    }
}

#pragma mark - AVAudioPlayerDelegate methods

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) flag {
    [AppDelegate setDefaultAudioSession];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[AppDelegate instance] resignFirstResponder];

    if (self.repeatState == HXOAudioPlayerRepeatStateOne) {
        [self play];
    } else {
        if (self.playlistIndex < [self.playlist count] - 1) {
            [self skipForward];
        } else {
            if (self.repeatState == HXOAudioPlayerRepeatStateAll) {
                [self playAtIndex:0];
            } else {
                [self stop];
            }
        }
    }
}

- (void) audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self stop];
}

@end
