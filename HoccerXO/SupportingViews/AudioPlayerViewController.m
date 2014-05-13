//
//  AudioPlayerViewController.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 02/05/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioPlayerViewController.h"
#import "Attachment.h"
#import "AttachmentInfo.h"
#import "HXOAudioPlayer.h"

@interface AudioPlayerViewController ()

@property (nonatomic, readonly) HXOAudioPlayer * audioPlayer;
@property (nonatomic, strong) NSTimer * playbackTimer;
@property (nonatomic, assign) BOOL isSeeking;

@end

@implementation AudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _audioPlayer = [HXOAudioPlayer sharedInstance];
    
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(attachment)) options:0 context:NULL];
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
    
    [self.playButton addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipBackButton addTarget:self action:@selector(skipBack:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipForwardButton addTarget:self action:@selector(skipForward:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider addTarget:self action:@selector(startSeekingTime:) forControlEvents:UIControlEventTouchDown];
    [self.seekSlider addTarget:self action:@selector(seekTime:) forControlEvents:UIControlEventValueChanged];

    [self updateAttachmentInfo];
    [self updatePlaybackState];
    [self updateCurrentTime];
    
    self.volumeDownImage.image = [self.volumeDownImage.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.volumeUpImage.image = [self.volumeUpImage.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void) viewDidAppear:(BOOL)animated {
    self.playbackTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateCurrentTime) userInfo:nil repeats:YES];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self.playbackTimer invalidate];
}

- (void) dealloc {
    [self.audioPlayer removeObserver:self forKeyPath:NSStringFromSelector(@selector(attachment))];
    [self.audioPlayer removeObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying))];

    [self.playButton removeTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipBackButton removeTarget:self action:@selector(skipBack:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider removeTarget:self action:@selector(seekTime:) forControlEvents:UIControlEventValueChanged];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    if ([keyPath isEqual:NSStringFromSelector(@selector(attachment))]) {
        [self updateAttachmentInfo];
    } else if ([keyPath isEqual:NSStringFromSelector(@selector(isPlaying))]) {
        [self updatePlaybackState];
    }
}

- (void) updateAttachmentInfo {
    Attachment *attachment = self.audioPlayer.attachment;

    AttachmentInfo *attachmentInfo = [[AttachmentInfo alloc] initWithAttachment:attachment];
    self.titleLabel.text = attachmentInfo.audioTitle;
    self.artistLabel.text = attachmentInfo.audioArtist;

    self.seekSlider.minimumValue = 0.0f;
    self.seekSlider.maximumValue = self.audioPlayer.duration;
    
    [attachment loadImage:^(UIImage *image, NSError *error) {
        self.artworkImage.image = image;
    }];
}

- (void) updatePlaybackState {
    NSString *imageName = [self.audioPlayer isPlaying] ? @"fullscreen-button-pause" : @"fullscreen-button-play";
    UIImage *image = [UIImage imageNamed:imageName];
    [self.playButton setImage:image forState:UIControlStateNormal];
}

- (void) updateCurrentTime {
    self.currentTimeLabel.text = [self stringFromTimeInterval:self.audioPlayer.currentTime];
    self.remainingTimeLabel.text = [self stringFromTimeInterval:(self.audioPlayer.currentTime - self.audioPlayer.duration)];

    if (!self.isSeeking) {
        self.seekSlider.value = self.audioPlayer.currentTime;
    }
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)abs(round(interval));
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);

    NSString *sign = interval <= -0.5 ? @"-" : @"";

    if (hours > 0) {
        return [NSString stringWithFormat:@"%@%i:%02i:%02i", sign, hours, minutes, seconds];
    }

    return [NSString stringWithFormat:@"%@%02i:%02i", sign, minutes, seconds];
}

- (void) togglePlayback: (id)sender {
    [self.audioPlayer togglePlayPause];
}

- (void) startSeekingTime: (id)sender {
    self.isSeeking = YES;
}

- (void) seekTime: (id)sender {
    self.audioPlayer.currentTime = self.seekSlider.value;
    self.isSeeking = NO;
}

- (void) skipBack: (id)sender {
    [self.audioPlayer skipBack];
    [self updateCurrentTime];
}

- (void) skipForward: (id)sender {
    [self.audioPlayer skipForward];
    [self updateCurrentTime];
}

@end
