//
//  FeedbackProvider.h
//  Hoccer
//
//  Created by Robert Palmer on 12.10.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface SoundEffectPlayer : NSObject

+ (void)messageArrived;
+ (void)messageDelivered;
+ (void)messageSent;
+ (void)throwDetected;
+ (void)catchDetected;

+ (void)playSoundWithId: (SystemSoundID)soundId;

@end
