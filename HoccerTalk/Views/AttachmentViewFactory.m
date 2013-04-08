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

+ (UIView*) viewForAttachment: (Attachment*) attachment inCell:(MessageCell*) cell {
    if (attachment == nil) {
        return nil;
    } else if ([attachment.mediaType isEqualToString:@"image"] ||
               [attachment.mediaType isEqualToString:@"video"] ||
               [attachment.mediaType isEqualToString:@"audio"])
    {
        UIView * attachmentView = [[UIView alloc] init];
        attachmentView.userInteractionEnabled = YES;
        CGRect frame = attachmentView.frame;
        
        UIImageView * imageView = [[UIImageView alloc] init];
        
        // preset frame to correct aspect ratio before actual image is loaded
        frame.size.width = attachment.aspectRatio;
        frame.size.height = 1.0;
        imageView.frame = frame;
        //imageView.userInteractionEnabled = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        [attachmentView addSubview:imageView];
        attachmentView.frame = frame;
        
        UIButton * myButton = [[UIButton alloc] initWithFrame: frame];
        [myButton setTitle:@"Open" forState:UIControlStateNormal];
        myButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        [myButton addTarget:cell action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];
        
        [attachmentView addSubview:myButton];
        
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
        return attachmentView;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return nil;
}

+ (CGFloat) heightOfAttachmentView: (Attachment*) attachment withViewOfWidth: (CGFloat) width {
    if (attachment == nil) {
        return 0;
    } else if ([attachment.mediaType isEqualToString:@"image"] ||
               [attachment.mediaType isEqualToString:@"video"] ||
               [attachment.mediaType isEqualToString:@"audio"]) {
        return width / attachment.aspectRatio;
    } else {
        NSLog(@"Unhandled attachment type");
    }
    return 0;
}

@end
