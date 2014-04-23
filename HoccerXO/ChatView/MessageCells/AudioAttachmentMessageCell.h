//
//  AudioAttachmentMessageCell.h
//  HoccerXO
//
//  Created by Nico Nußbaum on 23/04/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@interface AudioAttachmentMessageCell : MessageCell <AttachmentMessageCell>

@property (nonatomic,readonly) AttachmentSection* attachmentSection;

@end
