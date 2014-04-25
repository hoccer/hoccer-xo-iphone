//
//  HXOAudioPlayer.h
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

#import "Attachment.h"

@interface HXOAudioPlayer : NSObject <AVAudioPlayerDelegate>

+ (HXOAudioPlayer *) sharedInstance;

- (BOOL) playURL: (NSURL *) url;
- (void) pause;

@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) NSURL * url;

@end
