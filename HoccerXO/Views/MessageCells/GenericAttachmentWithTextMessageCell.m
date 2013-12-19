//
//  GenericAttachmentWithTextMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GenericAttachmentWithTextMessageCell.h"

#import "GenericAttachmentSection.h"
#import "TextSection.h"

extern CGFloat kHXOGridSpacing;

@implementation GenericAttachmentWithTextMessageCell

- (void) commonInit {
    [super commonInit];

    _attachmentSection = [[GenericAttachmentSection alloc] initWithFrame: CGRectMake(0, 0, self.bubbleWidth, 0)];
    [self addSection: self.attachmentSection];

    [self addSection: [[TextSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, 5 * kHXOGridSpacing)]];
    
}

@end
