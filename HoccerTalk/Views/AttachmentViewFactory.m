//
//  AttachmentViewFactory.m
//  HoccerTalk
//
//  Created by David Siegel on 14.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentViewFactory.h"

#import "Attachment.h"
#import "ImageAttachment.h"
#import <QuartzCore/QuartzCore.h>

@implementation AttachmentViewFactory

+ (UIView*) viewForAttachment: (Attachment*) attachment {
    if (attachment == nil) {
        return nil;
    } else if ([attachment isKindOfClass: [ImageAttachment class]]) {
        UIImageView * imageView = [[UIImageView alloc] initWithImage: [UIImage imageWithContentsOfFile: attachment.filePath]];
        /*
        imageView.layer.shadowColor = [UIColor blackColor].CGColor;
        imageView.layer.shadowOffset = CGSizeMake(0, 2);
        imageView.layer.shadowOpacity = 0.8;
        imageView.layer.shadowRadius = 3;
        imageView.layer.masksToBounds = NO;
         */
        return imageView;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return nil;
}

+ (CGFloat) heightOfAttachmentView: (Attachment*) attachment withViewOfWidth: (CGFloat) width {
    if (attachment == nil) {
        return 0;
    } else if ([attachment isKindOfClass: [ImageAttachment class]]) {
        ImageAttachment * imageAttachment = (ImageAttachment*)attachment;
        return width * imageAttachment.aspectRatio;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return 0;
}

@end
