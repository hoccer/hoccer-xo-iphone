//
//  MessageCell.m
//  Hoccenger
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@implementation MessageCell

enum { kMessagePadding = 20 };

- (float) heightForText: (NSString*) text {
    return MAX(kMessagePadding + [self.myMessage calculateSize: text].height + kMessagePadding,
               self.frame.size.height);
}

+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

@end
