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

- (NSTimeInterval) currentTime {
    if (self.player) {
        return self.player.currentTime;
    } else {
        return 0.0f;
    }
}

- (NSTimeInterval) duration {
    if (self.player) {
        return self.player.duration;
    } else {
        return 0.0f;
    }
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

        [nowPlayingInfo setValue:[NSNumber numberWithDouble: attachmentInfo.audioDuration] forKey:MPMediaItemPropertyPlaybackDuration];

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
