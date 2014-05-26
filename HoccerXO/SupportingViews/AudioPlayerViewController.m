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
#import "NSString+FromTimeInterval.h"
#import "player_close.h"
#import "player_button_play.h"
#import "player_button_pause.h"
#import "player_button_next.h"
#import "player_button_prev.h"
#import "player_icon_volume_down.h"
#import "player_icon_volume_up.h"
#import "UIImage+ImageEffects.h"

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
    
    [self.closeButton setImage:[[[player_close alloc] init] image] forState:UIControlStateNormal];
    [self.skipBackButton setImage:[[[player_button_prev alloc] init] image] forState:UIControlStateNormal];
    [self.skipForwardButton setImage:[[[player_button_next alloc] init] image] forState:UIControlStateNormal];
    
    [self.closeButton addTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];
    [self.playButton addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipBackButton addTarget:self action:@selector(skipBack:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipForwardButton addTarget:self action:@selector(skipForward:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider addTarget:self action:@selector(startSeekingTime:) forControlEvents:UIControlEventTouchDown];
    [self.seekSlider addTarget:self action:@selector(seekTime:) forControlEvents:UIControlEventValueChanged];

    [self updateAttachmentInfo];
    [self updatePlaybackState];
    [self updateCurrentTime];
    
    self.volumeDownImageView.image = [[[player_icon_volume_down alloc] init] image];
    self.volumeUpImageView.image = [[[player_icon_volume_up alloc] init] image];
    self.seekSlider.tintColor = self.view.tintColor;
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

    [self.closeButton removeTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];
    [self.playButton removeTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipBackButton removeTarget:self action:@selector(skipBack:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipForwardButton removeTarget:self action:@selector(skipForward:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider removeTarget:self action:@selector(startSeekingTime:) forControlEvents:UIControlEventTouchDown];
    [self.seekSlider removeTarget:self action:@selector(seekTime:) forControlEvents:UIControlEventValueChanged];
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
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

    if (attachment) {
        AttachmentInfo *attachmentInfo = [[AttachmentInfo alloc] initWithAttachment:attachment];
        self.titleLabel.text = attachmentInfo.audioTitle;
        self.artistLabel.text = attachmentInfo.audioArtist;

        self.seekSlider.minimumValue = 0.0f;
        self.seekSlider.maximumValue = self.audioPlayer.duration;
        
        [attachment loadImage:^(UIImage *image, NSError *error) {
            self.artworkImageView.image = image;
            self.view.layer.contents = (id)[image applyBlurWithRadius: 3 * kHXOGridSpacing tintColor:[UIColor colorWithWhite:0.1 alpha:0.6] saturationDeltaFactor: 1.0 maskImage: nil].CGImage;
            self.view.layer.contentsRect = CGRectMake(0.22, 0, 0.56, 1);
        }];
        
        HXOAudioPlayer *player = [HXOAudioPlayer sharedInstance];
        self.playlistStatusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"audio_player_playlist_status", nil), player.playlistIndex + 1, player.playlistLength];
    } else {
        [self close:nil];
    }
}

- (void) updatePlaybackState {
    if ([self.audioPlayer isPlaying]){
        UIImage *image = [[[player_button_pause alloc] init] image];
        [self.playButton setImage:image forState:UIControlStateNormal];
    } else {
        UIImage *image = [[[player_button_play alloc] init] image];
        [self.playButton setImage:image forState:UIControlStateNormal];
    }
    
}

- (void) updateCurrentTime {
    self.currentTimeLabel.text = [NSString stringFromTimeInterval:self.audioPlayer.currentTime];
    self.remainingTimeLabel.text = [NSString stringFromTimeInterval:(self.audioPlayer.currentTime - self.audioPlayer.duration)];

    if (!self.isSeeking) {
        self.seekSlider.value = self.audioPlayer.currentTime;
    }
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

- (void) close: (id)sender {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
