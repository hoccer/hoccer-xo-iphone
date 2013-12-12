//
//  ImageAttachmentMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentMessageCell.h"
#import "ImageAttachmentSection.h"

@interface ImageAttachmentMessageCell ()


@end

@implementation ImageAttachmentMessageCell

- (void) commonInit {
    [super commonInit];

    _imageAttachmentSection = [[ImageAttachmentSection alloc] initWithFrame:CGRectMake(0, self.gridSpacing, self.bubbleWidth, 5 * self.gridSpacing)];
    [self addSection: self.imageAttachmentSection];
}


@end
