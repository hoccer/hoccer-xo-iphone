//
//  AudioAttachmentSection.h
//  HoccerXO
//
//  Created by Nico Nußbaum on 23/04/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AttachmentSection.h"

@class HXOAudioPlaybackButton;

@interface AudioAttachmentSection : AttachmentSection

@property (nonatomic,readonly) UILabel * title;
@property (nonatomic,readonly) HXOAudioPlaybackButton * playbackButton;

@end
