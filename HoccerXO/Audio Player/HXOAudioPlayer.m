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
#import "MessageItem.h"


@interface HXOAudioPlayer ()

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) Attachment * attachment;
@property (nonatomic, strong) AVAudioPlayer * player;

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

#pragma mark - Public interface

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

- (void) play {
    [self playAttachment:self.attachment];
}

- (void) pause {
    [self.player pause];
    self.isPlaying = NO;
}

- (void) stop {
    [self pause];
    self.attachment = nil;
}

#pragma mark - Private helpers

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

- (void) updateNowPlayingInfo {
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    if (self.attachment) {
        MessageItem *messageItem = [[MessageItem alloc] initWithMessage:self.attachment.message];
        NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionary];
        
        if (messageItem.audioTitle) {
            [nowPlayingInfo setValue:messageItem.audioTitle forKey:MPMediaItemPropertyTitle];
        } else {
            [nowPlayingInfo setValue:self.attachment.humanReadableFileName forKey:MPMediaItemPropertyTitle];
        }

        if (messageItem.audioArtist) {
            [nowPlayingInfo setValue:messageItem.audioArtist forKey:MPMediaItemPropertyArtist];
        }

        if (messageItem.audioAlbum) {
            [nowPlayingInfo setValue:messageItem.audioAlbum forKey:MPMediaItemPropertyAlbumTitle];
        }

        [nowPlayingInfo setValue:[NSNumber numberWithDouble: messageItem.audioDuration] forKey:MPMediaItemPropertyPlaybackDuration];

        infoCenter.nowPlayingInfo = nowPlayingInfo;
    } else {
        infoCenter.nowPlayingInfo = nil;
    }
}

#pragma mark - AVAudioPlayerDelegate methods

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) flag {
    [AppDelegate setDefaultAudioSession];
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[AppDelegate instance] resignFirstResponder];

    [self stop];
}

- (void) audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    [self stop];
}

@end
