//
//  MessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatTableCells.h"
#import "AutoheightLabel.h"
#import "HXOMessage.h"
#import "InsetImageView.h"

@implementation MessageCell

/*
- (void)pressedButton: (id)sender {
    // NSLog(@"MessageCell pressedButton %@", sender);
    
    if (self.delegate != nil) {
        [self.delegate presentAttachmentViewForCell: self];
    }
}
*/

-(BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self canPerformAction:action withSender:sender];
    }
    return NO;
}

-(BOOL)canBecomeFirstResponder {
    return YES;
}

-(void) saveMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self saveMessage:sender];
    }
}

-(void) resendMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self resendMessage:sender];
    }
}

-(void) forwardMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self forwardMessage:sender];
    }
}

-(void) copy:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self copy:sender];
    }
}

-(void) deleteMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self deleteMessage:sender];
    }
}
@end


/*
@implementation ChatTableSectionHeaderCell

#if 0
// We dont't need it right now, but may come in handy for doing some section navigation
- (void) awakeFromNib {
    [super awakeFromNib];
    //[self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)]]; // add non-working longpress gesture recognizer to avoid crash
    self.userInteractionEnabled = NO;
    self.label.userInteractionEnabled = NO;
    self.backgroundImage.userInteractionEnabled = NO;
}
-(BOOL) canPerformAction:(SEL)action withSender:(id)sender {
     NSLog(@"ChatTableSectionHeaderCell:canPerformAction");
     return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    NSLog(@"ChatTableSectionHeaderCell:gestureRecognizerShouldBegin");
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    NSLog(@"ChatTableSectionHeaderCell:shouldReceiveTouch");
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    NSLog(@"ChatTableSectionHeaderCell:shouldRecognizeSimultaneouslyWithGestureRecognizer");
    return NO;
}

-(void)handleLongPress:(UILongPressGestureRecognizer*)longPressRecognizer {
    NSLog(@"ChatTableSectionHeaderCell:handleLongPress");
}
#endif


@end
 */

