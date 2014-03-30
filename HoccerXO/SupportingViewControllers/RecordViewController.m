//
//  RecordViewController.m
//  HoccerXO
//
//  Created by Pavel on 29.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "RecordViewController.h"
#import "ChatViewController.h"

#import "TDSemiModal.h"
#import "AppDelegate.h"

#define ENABLE_METERING NO

@interface RecordViewController ()

@property (nonatomic,assign) BOOL hasRecording;

@end

@implementation RecordViewController
{
    CGFloat disabledAlpha;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    disabledAlpha = 0.1;

    self.useButton.style = UIBarButtonItemStyleDone;
    self.useButton.title = NSLocalizedString(@"recorder_use_button_title", nil);
    
    NSDictionary *recordSettings = @{AVEncoderAudioQualityKey : @(AVAudioQualityMin),
                                     AVEncoderBitRateKey : @(16),
                                     AVNumberOfChannelsKey : @(2),
                                     AVSampleRateKey : @(44100.0),
                                     AVFormatIDKey: @(kAudioFormatMPEG4AAC)};
    
    
    NSError *error = nil;
    
    _audioRecorder = [[AVAudioRecorder alloc]
                      initWithURL:[self ensureAudioURL]
                      settings:recordSettings
                      error:&error];
    
    if (error) {
        NSLog(@"error: %@", [error localizedDescription]);
    } else {
        _audioRecorder.delegate = self;
        [_audioRecorder prepareToRecord];
    }
    // NSLog(@"Audiorecorder prepared, URL: %@", self.audioFileURL);
    [self updateStatusDisplay];
    [self updateTimeDisplay:nil];
    
    self.useButton.enabled = NO;
    [AppDelegate requestRecordPermission];

    [self updateButtons];
}

- (void) viewWillAppear:(BOOL)animated {
    self.hasRecording = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSURL*) ensureAudioURL {
    if (self.audioFileURL == nil) {
        NSString * newFileName = @"recording.m4a";
        self.audioFileURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];
    }
    return self.audioFileURL;
}

#pragma mark -- Action methods

-(void) updateStatusDisplay {
    NSString * statusKey;
    if (_audioRecorder.recording) {
        statusKey = @"recorder_status_recording";
    } else if (_audioPlayer.playing) {
        statusKey = @"recorder_status_playing";
    } else {
        statusKey = @"recorder_status_stopped";
    }
    self.statusLabel.text = NSLocalizedString(statusKey, nil);
}

- (void) startTimer {
    // NSLog(@"startTimer:");
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(updateTimeDisplay:) userInfo:nil repeats:YES];
}

- (void) stopTimer {
    // NSLog(@"stopTimer:");
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void) updateButtons {
    NSString * recordStopKey;
    if (_audioRecorder.isRecording || _audioPlayer.isPlaying) {
        recordStopKey = @"recorder_stop_button_title";
    } else {
        recordStopKey = @"recorder_record_button_title";
    }
    [self.playButton setTitle: NSLocalizedString(@"recorder_play_button_title", nil) forState: UIControlStateNormal];
    [self.recordStopButton setTitle: NSLocalizedString(recordStopKey, nil) forState: UIControlStateNormal];

    self.useButton.enabled = self.hasRecording;
    BOOL playButtonEnabled = self.hasRecording && ! (_audioRecorder.isRecording || _audioPlayer.isPlaying);
    self.playButton.enabled = playButtonEnabled;
    self.playButton.alpha = playButtonEnabled ? 1.0 : 0.5;
}

- (void) updateTimeDisplay:(NSTimer *)theTimer {
    NSTimeInterval seconds = 0;
    if (_audioRecorder.recording) {
        seconds = _audioRecorder.currentTime;
        if (ENABLE_METERING) {
            [_audioRecorder updateMeters];
            NSLog(@"Average input: %f Peak input: %f", [_audioRecorder averagePowerForChannel:0], [_audioRecorder peakPowerForChannel:0]);
        }
    }
    if (_audioPlayer.playing) {
        seconds = _audioPlayer.currentTime;
    }
    NSString * myTime = [NSString stringWithFormat:@"%02d:%02d", (int)seconds/60, (int)seconds%60];
    // NSLog(@"myTime %@", myTime);
    self.timeLabel.text = myTime;
}

- (IBAction)play:(id)sender {
    if (_audioRecorder) {
        [AppDelegate setMusicAudioSession];
    }

    NSError *error;

    // NSLog(@"Audiorecorder init url: %@", _audioRecorder.url);

    _audioPlayer = [[AVAudioPlayer alloc]
                    initWithContentsOfURL:_audioRecorder.url
                    error:&error];

    _audioPlayer.delegate = self;

    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    } else {
        // NSLog(@"Audioplayer play: %@", _audioRecorder.url);
        [_audioPlayer play];
        [self startTimer];
    }
    [self updateButtons];
    [self updateStatusDisplay];
}

- (IBAction)recordOrStop:(id)sender {
    if (_audioRecorder.isRecording) {
        [self stopTimer];
        [_audioRecorder stop];
        [AppDelegate setDefaultAudioSession];
    } else if (_audioPlayer.isPlaying) {
        [self stopTimer];
        [_audioPlayer stop];
        [AppDelegate setDefaultAudioSession];
    } else {
        [AppDelegate setRecordingAudioSession];

        [_audioRecorder record];
        if (ENABLE_METERING) {
            _audioRecorder.meteringEnabled = YES;
        }
        [self startTimer];
        // NSLog(@"Audiorecorder record: %d", _audioRecorder.recording);
    }
    [self updateStatusDisplay];
    [self updateButtons];
}

- (void) stopAll {
    [_audioPlayer stop];
    [_audioRecorder stop];

}

#pragma mark -- Navigation action methods


- (IBAction)usePressed:(id)sender {
    // NSLog(@"usePressed:");
    [self stopAll];
	[self dismissSemiModalViewController:self];
    
    if (self.delegate != nil) {
        // NSLog(@"usePressed calling didRecordAudio %@",self.audioFileURL);
        [self.delegate audiorecorder:self didRecordAudio:self.audioFileURL];
    }
}

- (IBAction)cancelPressed:(id)sender {
    [self stopAll];
    [_audioRecorder deleteRecording];
	[self dismissSemiModalViewController:self];

}

#pragma mark -- delegate methods

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self updateButtons];
    [self updateStatusDisplay];
    [self stopTimer];
}

-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                error:(NSError *)error
{
    NSLog(@"Decode Error occurred, %@", error);
}

-(void)audioRecorderDidFinishRecording: (AVAudioRecorder *)recorder successfully:(BOOL)flag {
    NSLog(@"audioRecorderDidFinishRecording, successfully=%d", flag);
    self.hasRecording = flag;
    [self updateButtons];
    [self updateStatusDisplay];
}

-(void)audioRecorderEncodeErrorDidOccur: (AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"Encode Error occurred, %@", error);
}

@end
