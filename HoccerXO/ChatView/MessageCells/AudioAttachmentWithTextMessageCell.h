//
//  AudioAttachmentWithTextMessageCell.h
//  HoccerXO
//
//  Created by Nico Nußbaum on 24.04.2014
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@interface AudioAttachmentWithTextMessageCell : MessageCell <AttachmentMessageCell>

@property (nonatomic,readonly) AttachmentSection *      attachmentSection;

@end
