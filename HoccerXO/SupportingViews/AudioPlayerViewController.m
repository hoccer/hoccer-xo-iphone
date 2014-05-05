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

@end

@implementation AudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _audioPlayer = [HXOAudioPlayer sharedInstance];
    
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
    
    self.titleLabel.text = self.audioPlayer.attachment.humanReadableFileName;
    [self updatePlaybackState];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    [self updatePlaybackState];
}

- (void) updatePlaybackState {
    NSString *playState = [self.audioPlayer isPlaying] ? @"Pause" : @"Play";
    [self.playButton setTitle:playState forState:UIControlStateNormal];
}

@end
