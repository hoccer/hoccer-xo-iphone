//
//  AttachmentViewFactory.m
//  HoccerTalk
//
//  Created by David Siegel on 14.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentViewFactory.h"

#import <QuartzCore/QuartzCore.h>

#import "Attachment.h"

@implementation AttachmentViewFactory

+ (UIView*) viewForAttachment: (Attachment*) attachment {
    if (attachment == nil) {
        return nil;
    } else if ([attachment.mediaType isEqualToString:@"image"]) {
        UIImageView * imageView = [[UIImageView alloc] init];
        imageView.image = attachment.image;

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
    } else if ([attachment.mediaType isEqualToString:@"image"]) {
        return width / attachment.aspectRatio;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return 0;
}

@end
