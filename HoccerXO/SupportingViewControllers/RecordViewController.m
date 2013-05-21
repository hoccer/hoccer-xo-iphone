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
#import "UIButton+GlossyRounded.h"
#import "AppDelegate.h"

@interface RecordViewController ()
@end

@implementation RecordViewController
{
    CGFloat disabledAlpha;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    disabledAlpha = 0.1;

    [self.playButton makeRoundAndGlossy];
    [self.stopButton makeRoundAndGlossy];
    [self.recordButton makeRoundAndGlossy];
    
    self.useButton.style = UIBarButtonItemStyleDone;

    [self disablePlay];
    [self disableStop];
    [self enableRecord];
    
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
        [_audioRecorder prepareToRecord];
    }
    // NSLog(@"Audiorecorder prepared, URL: %@", self.audioFileURL);
    [self updateStatusDisplay];
    [self updateTimeDisplay:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSURL*) ensureAudioURL {
    if (self.audioFileURL == nil) {
        NSString * newFileName = @"recording.m4a";
        self.audioFileURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];        
    }
    return self.audioFileURL;
}

#pragma mark -- Action methods

-(void) updateStatusDisplay {
    if (_audioRecorder.recording) {
        self.statusLabel.text = @"Recording";
        return;
    }
    if (_audioPlayer.playing) {
        self.statusLabel.text = @"Playing";
        return;
    }
    self.statusLabel.text = @"Stopped";
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

- (void)enableStop {
    _stopButton.enabled = YES;
    _stopButton.alpha = 1.0;;
}

- (void)enablePlay {
    _playButton.enabled = YES;
    _playButton.alpha = 1.0;;
}

- (void)enableRecord {
    _recordButton.enabled = YES;
    _recordButton.alpha = 1.0;;
}

- (void)disableStop {
    _stopButton.enabled = NO;
    _stopButton.alpha = disabledAlpha;;
}

- (void)disablePlay {
    _playButton.enabled = NO;
    _playButton.alpha = disabledAlpha;;
}

- (void)disableRecord {
    _recordButton.enabled = NO;
    _recordButton.alpha = disabledAlpha;;
}

- (void) updateTimeDisplay:(NSTimer *)theTimer {
    NSTimeInterval seconds = 0;
    if (_audioRecorder.recording) {
        seconds = _audioRecorder.currentTime;
    }
    if (_audioPlayer.playing) {
        seconds = _audioPlayer.currentTime;
    }
    NSString * myTime = [NSString stringWithFormat:@"%02d:%02d", (int)seconds/60, (int)seconds%60];
    // NSLog(@"myTime %@", myTime);
    self.timeLabel.text = myTime;
}

- (IBAction)recordAudio:(id)sender {
    // NSLog(@"recordAudio:");
    if (!_audioRecorder.recording)
    {
        [self disablePlay];
        [self enableStop];
        
        [AppDelegate setRecordingAudioSession];

        [_audioRecorder record];
        [self startTimer];
        // NSLog(@"Audiorecorder record: %d", _audioRecorder.recording);
    }
    [self updateStatusDisplay];
}

- (IBAction)playAudio:(id)sender {
    if (!_audioRecorder.recording) {
        [self disableRecord];
        [self enableStop];
        
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
    }
    [self updateStatusDisplay];
}

- (IBAction)stop:(id)sender {
    [self enableRecord];
    [self enablePlay];
    [self disableStop];
    
    if (_audioRecorder.recording) {
        [self stopTimer];
        [_audioRecorder stop];
    } else if (_audioPlayer.playing) {
        [self stopTimer];
        [_audioPlayer stop];
    }
    [AppDelegate setDefaultAudioSession];
    
    [self updateStatusDisplay];
}

#pragma mark -- Navigation action methods


- (IBAction)usePressed:(id)sender {
    // NSLog(@"usePressed:");
    [self stop:nil];
	[self dismissSemiModalViewController:self];
    
    if (self.delegate != nil) {
        // NSLog(@"usePressed calling didRecordAudio %@",self.audioFileURL);
        [self.delegate audiorecorder:self didRecordAudio:self.audioFileURL];
    }
}

- (IBAction)cancelPressed:(id)sender {
    [self stop:nil];
    [_audioRecorder deleteRecording];
	[self dismissSemiModalViewController:self];

}

#pragma mark -- delegate methods

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self enableRecord];
    [self enablePlay];
    [self disableStop];
    _recordButton.enabled = YES;
    _stopButton.enabled = NO;
    [self updateStatusDisplay];
    [self stopTimer];
}

-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                error:(NSError *)error
{
    NSLog(@"Decode Error occurred, %@", error);
}

-(void)audioRecorderDidFinishRecording: (AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    // NSLog(@"audioRecorderDidFinishRecording, successfully=%d", flag);
    [self updateStatusDisplay];
}

-(void)audioRecorderEncodeErrorDidOccur: (AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"Encode Error occurred, %@", error);
}

@end
