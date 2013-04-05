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
    } else if ([attachment.mediaType isEqualToString:@"image"] ||
               [attachment.mediaType isEqualToString:@"video"]) {
        UIImageView * imageView = [[UIImageView alloc] init];
        CGRect frame = imageView.frame;
        
        // preset frame to correct aspect ratio before actual image is loaded
        frame.size.width = attachment.aspectRatio;
        frame.size.height = 1.0;
        imageView.frame = frame;
        
        if (attachment.image == nil) {
            [attachment loadImage:^(UIImage * image, NSError * error) {
                if (error == nil) {
                    imageView.image = image;
                    attachment.image = image;
                } else {
                    NSLog(@"viewForAttachment: failed to load attachment image, error=%@",error);
                }
            }];
        } else {
            imageView.image = attachment.image;
        }
        return imageView;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return nil;
}

+ (CGFloat) heightOfAttachmentView: (Attachment*) attachment withViewOfWidth: (CGFloat) width {
    if (attachment == nil) {
        return 0;
    } else if ([attachment.mediaType isEqualToString:@"image"] ||
               [attachment.mediaType isEqualToString:@"video"]) {
        return width / attachment.aspectRatio;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return 0;
}

@end
