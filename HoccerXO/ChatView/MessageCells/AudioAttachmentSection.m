//
//  AudioAttachmentSection.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 23/04/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentSection.h"

#import "MessageCell.h"
#import "UpDownLoadControl.h"
#import "HXOUI.h"
#import "HXOAudioPlaybackButton.h"

@implementation AudioAttachmentSection

- (void) commonInit {
    [super commonInit];
    
    _title = [[UILabel alloc] initWithFrame:CGRectMake(2 * kHXOGridSpacing, 0, self.bounds.size.width - 9 * kHXOGridSpacing, 32)];
    self.title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview: self.title];
    
    self.upDownLoadControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    
    _playbackButton = [[HXOAudioPlaybackButton alloc] initWithFrame: [self attachmentControlFrame]];
    self.playbackButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview: self.playbackButton];
    
    self.subtitle.frame = CGRectMake(2 * kHXOGridSpacing, 24, self.bounds.size.width - 9 * kHXOGridSpacing, 16);
    self.subtitle.font = [UIFont systemFontOfSize: 10];
    
}

- (CGSize) sizeThatFits:(CGSize)size {
    size.height = 6 * kHXOGridSpacing;
    return size;
}

- (void) colorSchemeDidChange {
    [super colorSchemeDidChange];
    self.title.textColor = [[HXOUI theme] messageAttachmentTitleColorForScheme: self.cell.colorScheme];
    self.subtitle.textColor = [[HXOUI theme] messageAttachmentSubtitleColorForScheme: self.cell.colorScheme];
    self.playbackButton.tintColor = [[HXOUI theme] messageAttachmentIconTintColorForScheme: self.cell.colorScheme];
}

- (CGRect) attachmentControlFrame {
    return CGRectMake(self.bounds.size.width - (2 * kHXOGridSpacing + 4 * kHXOGridSpacing), kHXOGridSpacing, 4 * kHXOGridSpacing, 4 * kHXOGridSpacing);
}

@end
