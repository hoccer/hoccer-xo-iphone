//
//  FeedbackProvider.m
//  Hoccer
//
//  Created by Robert Palmer on 12.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "SoundEffectPlayer.h"
#import "HXOUserDefaults.h"

void CreateSystemSoundIDFromWAVInRessources(CFStringRef name, SystemSoundID *id);

SystemSoundID messageArrivedId = 0;
SystemSoundID messageDeliveredId = 0;
SystemSoundID messageSentId = 0;
SystemSoundID transferFinishedId = 0;
SystemSoundID transferFailedId = 0;


@interface SoundEffectPlayer ()

+ (void)playSoundWithId: (SystemSoundID)soundId;

@end

void CreateSystemSoundIDFromWAVInRessources(CFStringRef name, SystemSoundID *id)
{
	CFBundleRef bundle = CFBundleGetMainBundle();
	CFURLRef soundUrl = CFBundleCopyResourceURL(bundle, name, CFSTR("wav"), NULL);
	AudioServicesCreateSystemSoundID(soundUrl, id);
	
	CFRelease(soundUrl);
}


@implementation SoundEffectPlayer

+  (void)initialize {
	CreateSystemSoundIDFromWAVInRessources(CFSTR("chime_sound"), &messageArrivedId);
	CreateSystemSoundIDFromWAVInRessources(CFSTR("catch_sound"), &messageDeliveredId);
	CreateSystemSoundIDFromWAVInRessources(CFSTR("sweep_out_sound"), &messageSentId);
	CreateSystemSoundIDFromWAVInRessources(CFSTR("tada_sound"), &transferFinishedId);
	CreateSystemSoundIDFromWAVInRessources(CFSTR("sad_trombone_sound"), &transferFailedId);
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
