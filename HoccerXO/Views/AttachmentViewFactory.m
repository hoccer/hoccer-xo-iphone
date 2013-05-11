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
#import "ChatTableCells.h"
#import "BubbleView.h"

@implementation AttachmentViewFactory

+ (AttachmentView*) viewForAttachment: (Attachment*) attachment inCell:(MessageCell*) cell {
    if (attachment == nil) {
        return nil;
    } else if ([attachment.mediaType isEqualToString:@"image"]       ||
               [attachment.mediaType isEqualToString:@"video"]       ||
               [attachment.mediaType isEqualToString:@"vcard"]       ||
               [attachment.mediaType isEqualToString:@"geolocation"] ||
               [attachment.mediaType isEqualToString:@"audio"])
    {
        AttachmentView * attachmentView = nil;
        if (attachment.progressIndicatorDelegate != nil) {
            NSLog(@"attachment has delegate");
            attachmentView = (AttachmentView*) (attachment.progressIndicatorDelegate);
            
            // when the delegate points to a view that is already in use by another attachment
            // or when it belongs to a different cell we will not reuse it and remove the delegate
            //if (![attachmentView.attachment isEqual: attachment] || ![attachmentView.cell isEqual: cell]) {
            if (attachmentView.attachment != attachment || attachmentView.cell != cell) {
                NSLog(@"attachment mismatch: %d, cell mismatch: %d", ![attachmentView.attachment isEqual: attachment], ![attachmentView.cell isEqual: cell]);
                
                attachment.progressIndicatorDelegate = nil; // remove delege
                return [AttachmentViewFactory viewForAttachment: attachment inCell: cell];
            }
            NSLog(@"reusing view");
        } else {
            if (cell.bubble.attachmentView == nil) {
                NSLog(@"fresh view");
                attachmentView = [[AttachmentView alloc] init];
            } else {
                NSLog(@"reuse view 2");
                // check if take away some other's attachments view a remove its delegate
                if (cell.bubble.attachmentView.attachment != attachment) {
                    NSLog(@"reuse view 2, removing other delegate");
                    cell.bubble.attachmentView.attachment.progressIndicatorDelegate = nil;
                }
                attachmentView = cell.bubble.attachmentView;
            }
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
    } else if ([attachment.mediaType isEqualToString:@"image"]       ||
               [attachment.mediaType isEqualToString:@"video"]       ||
               [attachment.mediaType isEqualToString:@"vcard"]       ||
               [attachment.mediaType isEqualToString:@"geolocation"] ||
               [attachment.mediaType isEqualToString:@"audio"])
    {
        return (attachment.aspectRatio > 0) ? width / attachment.aspectRatio : width;
    } else {
        NSLog(@"ERROR: AttachmentViewFactory:heightOfAttachmentView: Unhandled attachment type: '%@'",attachment.mediaType);
    }
    return 0;
}

@end
