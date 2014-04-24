//
//  HXOAudioPlaybackButtonController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOAudioPlaybackButtonController.h"
#import "HXOAudioPlayer.h"


@interface HXOAudioPlaybackButtonController ()

@property (nonatomic, strong) NSURL * audioURL;
@property (nonatomic, strong) UIButton * button;

@end


@implementation HXOAudioPlaybackButtonController

- (id) initWithButton: (UIButton *) button audioURL: (NSURL *)url {
    self = [super init];
    
    if (self) {
        self.audioURL = url;
        self.button = button;

        [[HXOAudioPlayer sharedInstance] addObserver:self forKeyPath:NSStringFromSelector(@selector(nowPlayingURL)) options:0 context:NULL];
        [self.button addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
        [self updatePlaybackState];
    }
    
    return self;
}

- (void) dealloc {
    [[HXOAudioPlayer sharedInstance] removeObserver:self forKeyPath:NSStringFromSelector(@selector(nowPlayingURL))];
    [self.button removeTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    [self updatePlaybackState];
}

- (void) updatePlaybackState {
    NSString *imageName = [self isPlaying] ? @"button-stop" : @"button-play";
    UIImage *image = [UIImage imageNamed:imageName];
    [self.button setImage:image forState:UIControlStateNormal];
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
