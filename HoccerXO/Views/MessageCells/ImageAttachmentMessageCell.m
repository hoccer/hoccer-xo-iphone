//
//  ImageAttachmentMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentMessageCell.h"
#import "ImageAttachmentSection.h"

@implementation ImageAttachmentMessageCell

- (void) commonInit {
    [super commonInit];
    _imageSection = [[ImageAttachmentSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, self.bubbleWidth)];
    [self addSection: self.imageSection];
}

- (AttachmentSection*) attachmentSection {
    return self.imageSection;
}

@end
