//
//  AttachmentViewFactory.m
//  HoccerXO
//
//  Created by David Siegel on 14.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentViewFactory.h"

#import <QuartzCore/QuartzCore.h>

#import "Attachment.h"
#import "HXOMessage.h"
#import "AttachmentView.h"

@implementation AttachmentViewFactory

+ (AttachmentView*) viewForAttachment: (Attachment*) attachment inCell:(MessageCell*) cell {
    if (attachment == nil) {
        return nil;
    } else if ([attachment.mediaType isEqualToString:@"image"] ||
               [attachment.mediaType isEqualToString:@"video"] ||
               [attachment.mediaType isEqualToString:@"vcard"] ||
               [attachment.mediaType isEqualToString:@"audio"])
    {
        AttachmentView * attachmentView = nil;
        if (attachment.progressIndicatorDelegate != nil) {
            attachmentView = (AttachmentView*) (attachment.progressIndicatorDelegate);
            if (attachmentView.attachment != attachment || attachmentView.cell != cell) {
                attachment.progressIndicatorDelegate = nil;
                return [AttachmentViewFactory viewForAttachment: attachment inCell: cell];
            }
        } else {
            attachmentView = [[AttachmentView alloc] init];
            attachment.progressIndicatorDelegate = attachmentView;
        }
        [attachmentView configureViewForAttachment: attachment inCell: cell];
        return attachmentView;
    } else {
        NSLog(@"ERROR: AttachmentViewFactory:viewForAttachment: Unhandled attachment type: '%@'",attachment.mediaType);
    }
    return nil;
}


+ (CGFloat) heightOfAttachmentView: (Attachment*) attachment withViewOfWidth: (CGFloat) width {
    if (attachment == nil) {
        return 0;
    } else if ([attachment.mediaType isEqualToString:@"image"] ||
               [attachment.mediaType isEqualToString:@"video"] ||
               [attachment.mediaType isEqualToString:@"vcard"] ||
               [attachment.mediaType isEqualToString:@"audio"])
    {
        return (attachment.aspectRatio > 0) ? width / attachment.aspectRatio : width;
    } else {
        NSLog(@"ERROR: AttachmentViewFactory:heightOfAttachmentView: Unhandled attachment type: '%@'",attachment.mediaType);
    }
    return 0;
}

@end
