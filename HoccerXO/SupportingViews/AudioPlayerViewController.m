//
//  AudioPlayerViewController.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 02/05/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioPlayerViewController.h"
#import "Attachment.h"
#import "HXOAudioPlayer.h"

@interface AudioPlayerViewController ()

@property (nonatomic, readonly) HXOAudioPlayer * audioPlayer;
@property (nonatomic, strong) NSTimer * playbackTimer;

@end

@implementation AudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _audioPlayer = [HXOAudioPlayer sharedInstance];
    
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
    
    // TODO: dump that code for playlist
    self.titleLabel.text = self.audioPlayer.attachment.humanReadableFileName;
    self.seekSlider.minimumValue = 0.0f;
    self.seekSlider.maximumValue = self.audioPlayer.duration;

    [self.playButton addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider addTarget:self action:@selector(seekTime:) forControlEvents:UIControlEventValueChanged];
    [self updatePlaybackState];
    [self updateCurrentTime];
}

- (void) viewDidAppear:(BOOL)animated {
    self.playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateCurrentTime) userInfo:nil repeats:YES];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self.playbackTimer invalidate];
}

- (void) dealloc {
    [self.audioPlayer removeObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying))];
    [self.playButton removeTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    [self updatePlaybackState];
}

- (void) updatePlaybackState {
    NSString *playState = [self.audioPlayer isPlaying] ? @"Pause" : @"Play";
    [self.playButton setTitle:playState forState:UIControlStateNormal];
}

- (void) updateCurrentTime {
    self.currentTimeLabel.text = [self stringFromTimeInterval:self.audioPlayer.currentTime];
    self.remainingTimeLabel.text = [self stringFromTimeInterval:(self.audioPlayer.currentTime - self.audioPlayer.duration)];
    self.seekSlider.value = self.audioPlayer.currentTime;
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)abs(round(interval));
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);

    NSString *sign = interval < 0.0f ? @"-" : @"";

    if (hours > 0) {
        return [NSString stringWithFormat:@"%@%i:%02i:%02i", sign, hours, minutes, seconds];
    }

    return [NSString stringWithFormat:@"%@%02i:%02i", sign, minutes, seconds];
}

- (void) togglePlayback: (id)sender {
    if ([self.audioPlayer isPlaying]) {
        [self.audioPlayer pause];
    } else {
        [self.audioPlayer play];
    }
}

- (void) seekTime: (id)sender {
    self.audioPlayer.currentTime = self.seekSlider.value;
}

@end
