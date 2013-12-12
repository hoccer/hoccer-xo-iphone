//
//  ImageAttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachmentSection.h"

@implementation ImageAttachmentSection

- (void) drawRect:(CGRect)rect {
    if (self.image != nil) {
        CGContextRef context = UIGraphicsGetCurrentContext();

        UIBezierPath * path = [self bubblePath];
        CGContextSaveGState(context);
        [path addClip];
    } else {
        [super drawRect:rect];
    }
}

@end