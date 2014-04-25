//
//  HXOAudioPlayer.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioPlayer.h"


@interface HXOAudioPlayer ()

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) AVAudioPlayer *player;

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

- (void) playURL: (NSURL *) url {
    [self ensurePlayerForURL:url];
    [self.player play];
    self.isPlaying = YES;
}

- (void) pause {
    [self.player pause];
    self.isPlaying = NO;
}

- (NSURL *) url {
    if (self.player) {
        return self.player.url;
    } else {
        return nil;
    }
}

#pragma mark - Private helpers

- (void) ensurePlayerForURL: (NSURL *) url {
    if (![self.url isEqual:url]) {
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        [self.player setDelegate:self];
    }
}

#pragma mark - AVAudioPlayerDelegate methods

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) flag {
    self.player = nil;
    self.isPlaying = NO;
}

@end
