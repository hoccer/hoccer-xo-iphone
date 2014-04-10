//
//  ImageAttachmentMessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@class ImageAttachmentSection;

@interface ImageAttachmentMessageCell : MessageCell <AttachmentMessageCell>

@property (nonatomic,readonly) AttachmentSection * attachmentSection;
@property (nonatomic,readonly) ImageAttachmentSection * imageSection;

@end
