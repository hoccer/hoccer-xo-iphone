//
//  AttachmentViewFactory.h
//  HoccerXO
//
//  Created by David Siegel on 14.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AttachmentView;
@class Attachment;
@class MessageCell;

@interface AttachmentViewFactory : NSObject

+ (AttachmentView *) viewForAttachment: (Attachment*) attachment inCell:(MessageCell*) cell;
+ (CGFloat) heightOfAttachmentView: (Attachment*) attachment withViewOfWidth: (CGFloat) width;

@end
