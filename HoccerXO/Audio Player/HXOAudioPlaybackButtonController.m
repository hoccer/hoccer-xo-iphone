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

@property (nonatomic, readonly) HXOAudioPlayer * audioPlayer;
@property (nonatomic, strong) NSURL * audioURL;
@property (nonatomic, strong) UIButton * button;

@end


@implementation HXOAudioPlaybackButtonController

- (id) initWithButton: (UIButton *) button audioURL: (NSURL *)url {
    self = [super init];
    
    if (self) {
        _audioPlayer = [HXOAudioPlayer sharedInstance];
        self.audioURL = url;
        self.button = button;

        [self.audioPlayer addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
        [self.button addTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
        [self updatePlaybackState];
    }
    
    return self;
}

- (void) dealloc {
    [self.audioPlayer removeObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying))];
    [self.button removeTarget:self action:@selector(togglePlayback:) forControlEvents:UIControlEventTouchUpInside];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    [self updatePlaybackState];
}

- (void) updatePlaybackState {
    NSString *imageName = [self isPlaying] ? @"button-pause" : @"button-play";
    UIImage *image = [UIImage imageNamed:imageName];
    [self.button setImage:image forState:UIControlStateNormal];
}

- (BOOL) isPlaying {
    return [self.audioPlayer isPlaying] && [self.audioPlayer.url isEqual:self.audioURL];
}

- (void) togglePlayback: (id) sender {
    if ([self isPlaying]) {
        [[HXOAudioPlayer sharedInstance] pause];
    } else {
        BOOL success = [[HXOAudioPlayer sharedInstance] playURL:self.audioURL];
        
        if (!success) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"attachment_cannot_play_title", nil)
                                                             message: NSLocalizedString(@"attachment_cannot_play_message", nil)
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                   otherButtonTitles: nil];
            [alert show];
        }
    }
}

@end
