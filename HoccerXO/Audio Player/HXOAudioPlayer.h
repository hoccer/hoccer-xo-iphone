//
//  HXOAudioPlayer.h
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class Attachment;

@interface HXOAudioPlayer : NSObject <AVAudioPlayerDelegate>

+ (HXOAudioPlayer *) sharedInstance;

- (BOOL) playAttachment: (Attachment *) attachment;
- (void) play;
- (void) pause;
- (void) togglePlayPause;
- (void) skipBack;
- (void) skipForward;

@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) Attachment * attachment;
@property (nonatomic, readonly) NSTimeInterval duration;
@property NSTimeInterval currentTime;


@end
