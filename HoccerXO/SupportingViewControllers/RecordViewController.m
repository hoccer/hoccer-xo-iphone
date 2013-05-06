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

@interface RecordViewController ()

@end

@implementation RecordViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    _playButton.enabled = NO;
    _stopButton.enabled = NO;
    
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
    NSLog(@"Audiorecorder prepared, URL: %@", self.audioFileURL);
    [self updateStatusDisplay];
    [self updateTimeDisplay:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	//slide in the filter view from the bottom
	// [self slideIn];
    NSLog(@"viewWillAppear");
}

- (void)slideIn {
	
	//set initial location at bottom of view
    CGRect frame = self.sheetView.frame;
    frame.origin = CGPointMake(0.0, self.view.bounds.size.height);
    self.sheetView.frame = frame;
    [self.view addSubview:self.sheetView];
	
    //animate to new location, determined by height of the view in the NIB
    [UIView beginAnimations:@"presentWithSuperview" context:nil];
    frame.origin = CGPointMake(0.0, self.view.bounds.size.height - self.sheetView.bounds.size.height);
	
    self.sheetView.frame = frame;
    [UIView commitAnimations];
}

- (void) slideOut {
	
	//do what you need to do with information gathered from the custom action sheet. E.g., apply data filter on parent view.
	
	[UIView beginAnimations:@"removeFromSuperviewWithAnimation" context:nil];
	
    // Set delegate and selector to remove from superview when animation completes
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	
    // Move this view to bottom of superview
    CGRect frame = self.sheetView.frame;
    frame.origin = CGPointMake(0.0, self.view.bounds.size.height);
    self.sheetView.frame = frame;
	
    [UIView commitAnimations];
}

// Method called when removeFromSuperviewWithAnimation's animation completes
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if ([animationID isEqualToString:@"removeFromSuperviewWithAnimation"]) {
        [self.view removeFromSuperview];
    }
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
    NSLog(@"startTimer:");
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(updateTimeDisplay:) userInfo:nil repeats:YES];
}

- (void) stopTimer {
    NSLog(@"stopTimer:");
    [self.updateTimer invalidate];
    self.updateTimer = nil;
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
    NSLog(@"recordAudio:");
    if (!_audioRecorder.recording)
    {
        _playButton.enabled = NO;
        _stopButton.enabled = YES;
        // [_audioRecorder deleteRecording];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryRecord error:nil];
        [session setActive:YES error:nil];
        [_audioRecorder record];
        [self startTimer];
        NSLog(@"Audiorecorder record: %d", _audioRecorder.recording);
    }
    [self updateStatusDisplay];
}

- (IBAction)playAudio:(id)sender {
    if (!_audioRecorder.recording) {
        _stopButton.enabled = YES;
        _recordButton.enabled = NO;
        
        NSError *error;
        
        NSLog(@"Audiorecorder init url: %@", _audioRecorder.url);
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [session setActive:YES error:nil];
        _audioPlayer = [[AVAudioPlayer alloc]
                        initWithContentsOfURL:_audioRecorder.url
                        error:&error];
        
        _audioPlayer.delegate = self;
        
        if (error) {
            NSLog(@"Error: %@", [error localizedDescription]);
        } else {
            NSLog(@"Audioplayer play: %@", _audioRecorder.url);
            [_audioPlayer play];
            [self startTimer];
        }
    }
    [self updateStatusDisplay];
}

- (IBAction)stop:(id)sender {
    _stopButton.enabled = NO;
    _playButton.enabled = YES;
    _recordButton.enabled = YES;
    
    if (_audioRecorder.recording) {
        [self stopTimer];
        [_audioRecorder stop];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        int flags = AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation;
        [session setActive:NO withOptions:flags error:nil];
        NSLog(@"_audioRecorder stopped");
    } else if (_audioPlayer.playing) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        int flags = AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation;
        [session setActive:NO withOptions:flags error:nil];
        [self stopTimer];
        [_audioPlayer stop];
        NSLog(@"_audioPlayer stopped");
    }
    [self updateStatusDisplay];
}

#pragma mark -- Navigation action methods

#ifdef PRESENTED_VIEW
- (IBAction)usePressed:(id)sender {
    NSLog(@"usePressed:");
    [self dismissViewControllerAnimated: YES completion: nil];
    if (self.delegate != nil) {
        NSLog(@"usePressed calling didRecordAudio %@",self.audioFileURL);
        [self.delegate audiorecorder:self didRecordAudio:self.audioFileURL];
    }
}

- (IBAction)cancelPressed:(id)sender {
    [_audioRecorder deleteRecording];
    [self dismissViewControllerAnimated: YES completion: nil];
}
#else
- (IBAction)usePressed:(id)sender {
    NSLog(@"usePressed:");
    //[self dismissViewControllerAnimated: YES completion: nil];
    // [self.view removeFromSuperview];
	[self dismissSemiModalViewController:self];
    
    if (self.delegate != nil) {
        NSLog(@"usePressed calling didRecordAudio %@",self.audioFileURL);
        [self.delegate audiorecorder:self didRecordAudio:self.audioFileURL];
    }
}

- (IBAction)cancelPressed:(id)sender {
    [_audioRecorder deleteRecording];
    // [self dismissViewControllerAnimated: YES completion: nil];
    // [self.view removeFromSuperview];
	[self dismissSemiModalViewController:self];

}

#endif


#pragma mark -- delegate methods

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
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
    NSLog(@"audioRecorderDidFinishRecording, successfully=%d", flag);
    [self updateStatusDisplay];
}

-(void)audioRecorderEncodeErrorDidOccur: (AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"Encode Error occurred, %@", error);
}

@end
