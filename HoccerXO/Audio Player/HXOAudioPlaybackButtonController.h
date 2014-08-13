//
//  HXOAudioPlaybackButtonController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 24.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;

@interface HXOAudioPlaybackButtonController : NSObject

- (id) initWithButton: (UIButton *) button attachment: (Attachment *) attachment;

@end
