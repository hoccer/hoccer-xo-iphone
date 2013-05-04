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

NSDate * lastAlertSoundStart;
NSDate * lastEffectSoundStart;

const double minEffectSoundInterval = 0.5;
const double minAlertSoundInterval = 2.0;


@implementation SoundEffectPlayer

+  (void)initialize {
	[self createSoundWithName: @"new_message"        ofType: @"aif" withId: &messageArrivedId];
    [self createSoundWithName: @"catch_sound"        ofType: @"wav" withId: &messageDeliveredId];
    [self createSoundWithName: @"sweep_out_sound"    ofType: @"wav" withId: &messageSentId];
    lastAlertSoundStart = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    lastEffectSoundStart = [[NSDate alloc] initWithTimeIntervalSince1970:0];
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

// Will just play sound
+ (void)playSoundWithId: (SystemSoundID)soundId {
	if ([[[HXOUserDefaults standardUserDefaults] objectForKey:@"playEffectSounds"] boolValue]) {
        if ([lastEffectSoundStart timeIntervalSinceNow] < -minEffectSoundInterval) {
            AudioServicesPlaySystemSound(soundId);
            lastEffectSoundStart = [[NSDate alloc] init];
        }
	}
}

// will play sound or vibrate if phone is set to silent mode
+ (void)playAlertSoundWithId: (SystemSoundID)soundId {
	if ([[[HXOUserDefaults standardUserDefaults] objectForKey:@"playAlertSounds"] boolValue]) {
        if ([lastAlertSoundStart timeIntervalSinceNow] < -minAlertSoundInterval) {
            AudioServicesPlayAlertSound(soundId);
            lastAlertSoundStart = [[NSDate alloc] init];
        }
	}
}

+ (void)vibrate {
	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}




@end
