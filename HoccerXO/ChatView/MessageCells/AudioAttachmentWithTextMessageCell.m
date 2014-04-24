//
//  AudioAttachmentWithTextMessageCell.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 24.04.2014
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentWithTextMessageCell.h"

#import "AudioAttachmentSection.h"
#import "TextSection.h"

#import "HXOUI.h"

@implementation AudioAttachmentWithTextMessageCell

- (void) commonInit {
    [super commonInit];

    _attachmentSection = [[AudioAttachmentSection alloc] initWithFrame: CGRectMake(0, 0, self.bubbleWidth, self.bubbleWidth)];

    [self addSection: self.attachmentSection];
    [self addSection: [[TextSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, 5 * kHXOGridSpacing)]];
}

@end
