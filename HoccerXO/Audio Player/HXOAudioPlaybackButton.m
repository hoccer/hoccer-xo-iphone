//
//  HXOAudioPlaybackButton.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioPlaybackButton.h"
#import "HXOAudioPlayer.h"


@implementation HXOAudioPlaybackButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
        [[HXOAudioPlayer sharedInstance] addObserver:self forKeyPath:NSStringFromSelector(@selector(nowPlayingURL)) options:0 context:NULL];
        [self addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
        [self updatePlaybackState];
    }

    return self;
}

- (void) dealloc {
    [[HXOAudioPlayer sharedInstance] removeObserver:self forKeyPath:NSStringFromSelector(@selector(nowPlayingURL))];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    [self updatePlaybackState];
}

- (void) setAudioURL:(NSURL *)audioURL {
    _audioURL = audioURL;
    [self updatePlaybackState];
}

- (void) updatePlaybackState {
    NSString *title = [self isPlaying] ? @"■" : @"▶";
    [self setTitle:title forState:UIControlStateNormal];
}

- (BOOL) isPlaying {
    return self.audioURL && [[[HXOAudioPlayer sharedInstance] nowPlayingURL] isEqual:self.audioURL];
}

- (void) togglePlayback: (id) sender {
    if ([self isPlaying]) {
        [[HXOAudioPlayer sharedInstance] pause];
    } else if (self.audioURL) {
        [[HXOAudioPlayer sharedInstance] playURL:self.audioURL];
    }
}

@end
