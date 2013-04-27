//
//  MessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatTableCells.h"
#import "AutoheightLabel.h"
#import "BubbleView.h"
#import "HXOMessage.h"

@implementation MessageCell

static const double kCellPadding = 10.0;

- (CGFloat) heightForMessage: (HXOMessage*) message {
    return MAX(kCellPadding + [self.bubble heightForMessage: message] + kCellPadding,
               self.frame.size.height);
}

- (void)pressedButton: (id)sender {
    // NSLog(@"MessageCell pressedButton %@", sender);
    
    if (self.delegate != nil) {
        [self.delegate presentAttachmentViewForCell: self];
    }
}

-(BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageView:self canPerformAction:action withSender:sender];
    }
    return NO;
}

-(BOOL)canBecomeFirstResponder {
    return YES;
}

-(void) saveMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageView:self saveMessage:sender];
    }
}

-(void) resendMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageView:self resendMessage:sender];
    }
}

-(void) copy:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageView:self copy:sender];
    }
}

-(void) deleteMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageView:self deleteMessage:sender];
    }
}

@end


@implementation LeftMessageCell

- (void) awakeFromNib {
    self.bubble.pointingRight = NO;
}

@end


@implementation RightMessageCell

- (void) awakeFromNib {
    self.bubble.pointingRight = YES;
}

@end


@implementation ChatTableSectionHeaderCell
@end

