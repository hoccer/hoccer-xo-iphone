//
//  AudioAttachmentMessageCell.m
//  HoccerXO
//
//  Created by Nico Nußbaum on 23/04/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentMessageCell.h"
#import "AudioAttachmentSection.h"

@implementation AudioAttachmentMessageCell

- (void) commonInit {
    [super commonInit];
    _attachmentSection = [[AudioAttachmentSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, 0)];
    [self addSection: self.attachmentSection];
}

@end
