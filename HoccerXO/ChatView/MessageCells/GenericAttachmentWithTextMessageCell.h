//
//  GenericAttachmentWithTextMessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@interface GenericAttachmentWithTextMessageCell : MessageCell <AttachmentMessageCell>

@property (nonatomic,readonly) AttachmentSection* attachmentSection;

@end
