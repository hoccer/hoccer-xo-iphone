//
//  MessageCell.m
//  HoccerTalk
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"
#import "AutoheightLabel.h"
#import "BubbleView.h"
#import "Message.h"

@implementation MessageCell

static const double kCellPadding = 10.0;

- (CGFloat) heightForMessage: (Message*) message {
    return MAX(kCellPadding + [self.bubble heightForMessage: message] + kCellPadding,
               self.frame.size.height);
}

@end
