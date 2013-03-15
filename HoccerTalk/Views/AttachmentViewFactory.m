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
#import "ImageAttachment.h"

@implementation AttachmentViewFactory

+ (UIView*) viewForAttachment: (Attachment*) attachment {
    if (attachment == nil) {
        return nil;
    } else if ([attachment isKindOfClass: [ImageAttachment class]]) {
        UIImageView * imageView = [[UIImageView alloc] init];
        ImageAttachment * imageAttachment = (ImageAttachment*)attachment;
        [imageAttachment loadImage:^(UIImage* image, NSError* error) {
            if (image) {
                imageView.image = image;
            } else {
                NSLog(@"Failed to get image: %@", error);
            }
        }];
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
