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
#import "HXOUI.h"

#define ENABLE_METERING NO

static const CGFloat kRingWidth = 6.0;

@interface RecordViewController ()

@property (nonatomic, assign) BOOL           hasRecording;
@property (nonatomic, strong) CAShapeLayer * recordRingLayer;
@property (nonatomic, strong) CAShapeLayer * recordSymbolLayer;

@end

@implementation RecordViewController
{
    CGFloat disabledAlpha;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSDictionary *recordSettings = @{AVEncoderAudioQualityKey : @(AVAudioQualityMin),
                                     AVEncoderBitRateKey : @(16),
                                     AVNumberOfChannelsKey : @(2),
                                     AVSampleRateKey : @(44100.0),
                                     AVFormatIDKey: @(kAudioFormatMPEG4AAC)};
    
    
    NSError *error = nil;
    
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL: [self ensureAudioURL]
                                                 settings: recordSettings
                                                    error: &error];
    
    if (error) {
        NSLog(@"error: %@", [error localizedDescription]);
        return;
    }
    _audioRecorder.delegate = self;
    [_audioRecorder prepareToRecord];

    [AppDelegate requestRecordPermission];

    self.view.tintColor = [UIColor whiteColor];

    [self.useButton setTitle: NSLocalizedString(@"recorder_use_button_title", nil) forState: UIControlStateNormal];
    [self.playButton setTitle: NSLocalizedString(@"recorder_play_button_title", nil) forState: UIControlStateNormal];

    self.sheetView.layer.borderWidth = 1;
    self.sheetView.layer.borderColor = [UIColor colorWithWhite: 0.38 alpha: 1.0].CGColor;
    [self setupRecordButton];

    [self updateTimeDisplay:nil];
    [self updateButtons];
}

- (void) setupRecordButton {
    UIColor * recordRed = self.recordStopButton.backgroundColor;
    self.recordStopButton.backgroundColor = [UIColor clearColor];

    CGRect bounds = self.recordStopButton.bounds;
    CGFloat radius = 0.5 * bounds.size.width;
    CGPoint center = CGPointMake(radius, radius);

    self.recordRingLayer = [CAShapeLayer layer];
    self.recordRingLayer.frame = bounds;
    self.recordRingLayer.fillColor = [UIColor whiteColor].CGColor;
    UIBezierPath * path = [UIBezierPath bezierPathWithArcCenter: center radius: radius startAngle: 0 endAngle: 2 * M_PI clockwise: NO];
    [path closePath];
    [path appendPath: [UIBezierPath bezierPathWithArcCenter: center radius: radius - kRingWidth startAngle: 0 endAngle: 2 * M_PI clockwise: YES]];
    [path closePath];
    self.recordRingLayer.path = path.CGPath;
    [self.recordStopButton.layer addSublayer: self.recordRingLayer];

    self.recordSymbolLayer = [CAShapeLayer layer];
    self.recordSymbolLayer.frame = bounds;
    self.recordSymbolLayer.fillColor = recordRed.CGColor;
    self.recordSymbolLayer.path = [UIBezierPath bezierPathWithArcCenter: center radius: radius - (kRingWidth + 1) startAngle: 0 endAngle: 2 * M_PI clockwise: NO].CGPath;
    [self.recordStopButton.layer addSublayer: self.recordSymbolLayer];
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

- (void) startTimer {
    // NSLog(@"startTimer:");
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.07 target:self selector:@selector(updateTimeDisplay:) userInfo:nil repeats:YES];
}

- (void) stopTimer {
    // NSLog(@"stopTimer:");
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void) updateButtons {
    self.useButton.enabled = self.hasRecording;
    self.playButton.enabled = self.hasRecording;
    BOOL isActive = self.audioRecorder.isRecording || self.audioPlayer.isPlaying;
    self.recordSymbolLayer.path = (isActive ? [self stopSymbol] : [self recordSymbol]).CGPath;
}

- (UIBezierPath*) recordSymbol {
    return [UIBezierPath bezierPathWithOvalInRect: CGRectInset(self.recordStopButton.bounds, kRingWidth + 1,  kRingWidth + 1)];
}

- (UIBezierPath*) stopSymbol {
    CGRect bounds = self.recordStopButton.bounds;
    CGFloat inset = 0.3 * bounds.size.width;
    return [UIBezierPath bezierPathWithRoundedRect: CGRectInset(bounds, inset, inset) cornerRadius: 4];
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
    NSString * myTime = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)seconds / 60, (int)seconds % 60, (int)(100 * (seconds - floor(seconds)))];
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
}

-(void)audioRecorderEncodeErrorDidOccur: (AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"Encode Error occurred, %@", error);
}

@end
