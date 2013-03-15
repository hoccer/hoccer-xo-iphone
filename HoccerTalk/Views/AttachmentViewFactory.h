//
//  AttachmentViewFactory.h
//  HoccerTalk
//
//  Created by David Siegel on 14.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;

@interface AttachmentViewFactory : NSObject

+ (UIView*) viewForAttachment: (Attachment*) attachment;
+ (CGFloat) heightOfAttachmentView: (Attachment*) attachment withViewOfWidth: (CGFloat) width;

@end
