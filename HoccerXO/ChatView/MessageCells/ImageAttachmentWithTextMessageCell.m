//
//  ImageAttachmentWithTextMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentWithTextMessageCell.h"

#import "ImageAttachmentSection.h"
#import "TextSection.h"

#import "HXOUI.h"

@implementation ImageAttachmentWithTextMessageCell

- (void) commonInit {
    [super commonInit];

    _attachmentSection = [[ImageAttachmentSection alloc] initWithFrame: CGRectMake(0, 0, self.bubbleWidth, self.bubbleWidth)];

    [self addSection: self.attachmentSection];
    [self addSection: [[TextSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, 5 * kHXOGridSpacing)]];
}

@end
