//
//  MessageItem.h
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AttachmentInfo;
@class HXOMessage;

@interface MessageItem : NSObject

- (id) initWithMessage: (HXOMessage*) message;

@property (nonatomic,weak) HXOMessage * message;

@property (nonatomic,readonly) NSAttributedString * attributedBody;

@property (nonatomic,readonly) AttachmentInfo * attachmentInfo;

@end
