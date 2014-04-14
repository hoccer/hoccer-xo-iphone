//
//  CopyableLabel.m
//  HoccerXO
//
//  Created by David Siegel on 06.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CopyableLabel.h"

@implementation CopyableLabel

- (BOOL) canPerformAction: (SEL) action withSender: (id) sender {
    return action == @selector(copy:) ? YES : [super canPerformAction: action withSender:sender];
}


- (BOOL) canBecomeFirstResponder {
    return YES;
}


- (BOOL) becomeFirstResponder {
    if([super becomeFirstResponder]) {
        self.highlighted = YES;
        return YES;
    }
    return NO;
}


- (void) copy:(id)sender {
    UIPasteboard *board = [UIPasteboard generalPasteboard];
    [board setString: self.text];
    self.highlighted = NO;
    [self resignFirstResponder];
}

@end