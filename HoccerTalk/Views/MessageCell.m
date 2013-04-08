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
#import "TalkMessage.h"

@implementation MessageCell

static const double kCellPadding = 10.0;

- (CGFloat) heightForMessage: (TalkMessage*) message {
    return MAX(kCellPadding + [self.bubble heightForMessage: message] + kCellPadding,
               self.frame.size.height);
}

- (void)pressedButton: (id)sender {
    NSLog(@"MessageCell pressedButton %@", sender);
    
    if (self.delegate != nil) {
        [self.delegate presentAttachmentViewForCell: self];
    }
}

@end
