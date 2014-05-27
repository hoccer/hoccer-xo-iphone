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
#import "player_button_shuffle_on.h"
#import "player_button_repeat_off.h"
#import "player_button_repeat_title.h"
#import "player_button_repeat_all.h"
#import "player_button_shuffle_off.h"
#import "player_icon_volume_down.h"
#import "player_icon_volume_up.h"
#import "UIImage+ImageEffects.h"

@interface AudioPlayerViewController ()

@property (nonatomic, readonly) HXOAudioPlayer * audioPlayer;
@property (nonatomic, strong) NSTimer * playbackTimer;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, strong) UIImage * shuffleOnImage;
@property (nonatomic, strong) UIImage * shuffleOffImage;
@property (nonatomic, strong) UIImage * repeatOffImage;
@property (nonatomic, strong) UIImage * repeatOneImage;
@property (nonatomic, strong) UIImage * repeatAllImage;

@end

@implementation AudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _audioPlayer = [HXOAudioPlayer sharedInstance];
    
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(attachment)) options:0 context:NULL];
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(isShuffled)) options:0 context:NULL];
    [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(repeatState)) options:0 context:NULL];
    
    [self.closeButton setImage:[[[player_close alloc] init] image] forState:UIControlStateNormal];
    [self.skipBackButton setImage:[[[player_button_prev alloc] init] image] forState:UIControlStateNormal];
    [self.skipForwardButton setImage:[[[player_button_next alloc] init] image] forState:UIControlStateNormal];
    
    [self.closeButton addTarget:self action:@selector(close:) forControlEvents:UIControlEventTouchUpInside];
    [self.playButton addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipBackButton addTarget:self action:@selector(skipBack:) forControlEvents:UIControlEventTouchUpInside];
    [self.skipForwardButton addTarget:self action:@selector(skipForward:) forControlEvents:UIControlEventTouchUpInside];
    [self.shuffleButton addTarget:self action:@selector(toggleShuffle:) forControlEvents:UIControlEventTouchUpInside];
    [self.repeatButton addTarget:self action:@selector(toggleRepeat:) forControlEvents:UIControlEventTouchUpInside];
    [self.seekSlider addTarget:self action:@selector(startSeekingTime:) forControlEvents:UIControlEventTouchDown];
    [self.seekSlider addTarget:self action:@selector(seekTime:) forControlEvents:UIControlEventValueChanged];

    self.seekSlider.tintColor = self.view.tintColor;
    self.volumeDownImageView.image = [[[player_icon_volume_down alloc] init] image];
    self.volumeUpImageView.image = [[[player_icon_volume_up alloc] init] image];
    self.shuffleOnImage = [[[player_button_shuffle_on alloc] init] imageWithFrame:CGRectMake(0, 0, 32, 32)];
    self.shuffleOffImage = [[[player_button_shuffle_off alloc] init] imageWithFrame:CGRectMake(0, 0, 32, 32)];
    self.repeatOffImage = [[[player_button_repeat_off alloc] init] imageWithFrame:CGRectMake(0, 0, 34, 32)];
    self.repeatOneImage = [[[player_button_repeat_title alloc] init] imageWithFrame:CGRectMake(0, 0, 34, 32)];
    self.repeatAllImage = [[[player_button_repeat_all alloc] init] imageWithFrame:CGRectMake(0, 0, 34, 32)];

    [self updateAttachmentInfo];
    [self updatePlaybackState];
    [self updateShuffleState];
    [self updateRepeatState];
    [self updateCurrentTime];
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
    [self.shuffleButton removeTarget:self action:@selector(toggleShuffle:) forControlEvents:UIControlEventTouchUpInside];
    [self.repeatButton removeTarget:self action:@selector(toggleRepeat:) forControlEvents:UIControlEventTouchUpInside];
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
    } else if ([keyPath isEqual:NSStringFromSelector(@selector(isShuffled))]) {
        [self updateShuffleState];
    } else if ([keyPath isEqual:NSStringFromSelector(@selector(repeatState))]) {
        [self updateRepeatState];
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
            CGSize screenSize = [[UIScreen mainScreen] bounds].size;
            CGFloat aspectRatio = screenSize.width / screenSize.height;
            self.view.layer.contentsRect = CGRectMake(0.5 * (1 - aspectRatio), 0, aspectRatio, 1);
        }];
        
        [self updatePlaylistStatus];
    } else {
        [self close:nil];
    }
}

- (void) updatePlaylistStatus {
    HXOAudioPlayer *player = [HXOAudioPlayer sharedInstance];
    NSString *playlistStatus = [NSString stringWithFormat:NSLocalizedString(@"audio_player_playlist_status", nil), player.currentPlaylistTrackNumber + 1, player.playlistLength];
    
    CGFloat fontSize = self.playlistStatusLabel.font.pointSize;
    NSMutableAttributedString *attributedPlaylistStatus = [[NSMutableAttributedString alloc] initWithString:playlistStatus attributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize] }];
    NSArray *components = [playlistStatus componentsSeparatedByString:@" "];
    NSRange range = NSMakeRange([(NSString *)[components objectAtIndex:0] length] + 1, [(NSString *)[components objectAtIndex:1] length]);
    [attributedPlaylistStatus setAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:fontSize] } range:range];

    self.playlistStatusLabel.attributedText = attributedPlaylistStatus;
}

- (void) updatePlaybackState {
    if (self.audioPlayer.isPlaying) {
        UIImage *image = [[[player_button_pause alloc] init] image];
        [self.playButton setImage:image forState:UIControlStateNormal];
    } else {
        UIImage *image = [[[player_button_play alloc] init] image];
        [self.playButton setImage:image forState:UIControlStateNormal];
    }
    
}

- (void) updateShuffleState {
    if (self.audioPlayer.isShuffled) {
        [self.shuffleButton setImage:self.shuffleOnImage forState:UIControlStateNormal];
        self.shuffleButton.tintColor = self.view.tintColor;
    } else {
        [self.shuffleButton setImage:self.shuffleOffImage forState:UIControlStateNormal];
        self.shuffleButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    }
}

- (void) updateRepeatState {
    switch (self.audioPlayer.repeatState) {
        case HXOAudioPlayerRepeatStateOff:
            [self.repeatButton setImage:self.repeatOffImage forState:UIControlStateNormal];
            self.repeatButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
            break;
            
        case HXOAudioPlayerRepeatStateOne:
            [self.repeatButton setImage:self.repeatOneImage forState:UIControlStateNormal];
            self.repeatButton.tintColor = self.view.tintColor;
            break;
            
        case HXOAudioPlayerRepeatStateAll:
            [self.repeatButton setImage:self.repeatAllImage forState:UIControlStateNormal];
            self.repeatButton.tintColor = self.view.tintColor;
            break;
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

- (void) toggleShuffle: (id)sender {
    [self.audioPlayer toggleShuffle];
}

- (void) toggleRepeat: (id)sender {
    [self.audioPlayer toggleRepeat];
}

- (void) close: (id)sender {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
