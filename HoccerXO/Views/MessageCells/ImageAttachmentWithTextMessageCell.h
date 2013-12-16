//
//  ImageAttachmentWithTextMessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@class ImageAttachmentSection;

@interface ImageAttachmentWithTextMessageCell : MessageCell

@property (nonatomic,readonly) ImageAttachmentSection * imageSection;

@end
