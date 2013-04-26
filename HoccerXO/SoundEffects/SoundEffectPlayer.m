//
//  FeedbackProvider.m
//  Hoccer
//
//  Created by Robert Palmer on 12.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "SoundEffectPlayer.h"
#import "HXOUserDefaults.h"

SystemSoundID messageArrivedId = 0;
SystemSoundID messageDeliveredId = 0;
SystemSoundID messageSentId = 0;
SystemSoundID transferFinishedId = 0;
SystemSoundID transferFailedId = 0;

@implementation SoundEffectPlayer

+  (void)initialize {
	[self createSoundWithName: @"message_ding"       ofType: @"caf" withId: &messageArrivedId];
    [self createSoundWithName: @"catch_sound"        ofType: @"wav" withId: &messageDeliveredId];
    [self createSoundWithName: @"sweep_out_sound"    ofType: @"wav" withId: &messageSentId];
    [self createSoundWithName: @"tada_sound"         ofType: @"wav" withId: &transferFinishedId];
    [self createSoundWithName: @"sad_trombone_sound" ofType: @"wav" withId: &transferFailedId];
}

+ (void) createSoundWithName: (NSString*) name ofType: (NSString*) type withId: (SystemSoundID*) theId {
    NSString *path  = [[NSBundle mainBundle] pathForResource: name ofType: type];
    NSURL *pathURL = [NSURL fileURLWithPath : path];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef) pathURL, theId);
}

+ (void)messageArrived {
	[SoundEffectPlayer playAlertSoundWithId: messageArrivedId];
}

+ (void)messageDelivered {
	[SoundEffectPlayer playSoundWithId: messageDeliveredId];
}

+ (void)messageSent {
	[SoundEffectPlayer playSoundWithId: messageSentId];
}

+ (void)transferFinished {
	[SoundEffectPlayer playSoundWithId: transferFinishedId];}

+ (void)transferFailed {
	[SoundEffectPlayer playSoundWithId: transferFailedId];
}

// Will just play sound
+ (void)playSoundWithId: (SystemSoundID)soundId {
	if ([[[HXOUserDefaults standardUserDefaults] objectForKey:@"playEffectSounds"] boolValue]) {
		AudioServicesPlaySystemSound(soundId);
	}
}

// will play sound or vibrate if phone is set to silent mode
+ (void)playAlertSoundWithId: (SystemSoundID)soundId {
	if ([[[HXOUserDefaults standardUserDefaults] objectForKey:@"playAlertSounds"] boolValue]) {
		AudioServicesPlayAlertSound(soundId);
	}
}

+ (void)vibrate {
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}




@end
