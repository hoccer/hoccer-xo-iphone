//
//  CopyableUITextField.m
//  HoccerXO
//
//  Created by Pavel on 10.09.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//
// based on http://www.bartlettpublishing.com/site/bartpub/blog/3/entry/371

#import "CopyableUITextField.h"

@implementation CopyableUITextFieldResponderView
@synthesize contextGestureRecognizer = _contextGestureRecognizer;

- (id) initWithFrame: (CGRect) frame {
    self = [super initWithFrame: frame];
    
    self.contextGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action: @selector(longPressGestureDidFire:)];
    [self addGestureRecognizer: self.contextGestureRecognizer];
    
    return self;
}

- (void) longPressGestureDidFire: (id) sender {
    UILongPressGestureRecognizer *recognizer = sender;
    if(recognizer.state == UIGestureRecognizerStateBegan) {
        [self initiateContextMenu:sender];
    }
}

- (void) initiateContextMenu: (id) sender {
    [self becomeFirstResponder];
    UIMenuController *menu = [UIMenuController sharedMenuController];
    [menu setTargetRect: self.bounds inView: self];
    [menu setMenuVisible: YES animated: YES];
}

-(BOOL) canBecomeFirstResponder {
    return YES;
}

@end

@implementation CopyableUITextField
@synthesize contextGestureRecognizerViewForDisabled = _contextGestureRecognizerViewForDisabled;

-(id) initWithCoder: (NSCoder*) aDecoder {
    self = [super initWithCoder: aDecoder];
    [self addDisabledRecognizer];
    return self;
}

-(id) initWithFrame: (CGRect) frame {
    self = [super initWithFrame: frame];
    [self addDisabledRecognizer];
    return self;
}

-(void) addDisabledRecognizer {
    self.contextGestureRecognizerViewForDisabled = [[CopyableUITextFieldResponderView alloc] initWithFrame: self.bounds];
    self.contextGestureRecognizerViewForDisabled.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contextGestureRecognizerViewForDisabled.userInteractionEnabled = NO;
    [self addSubview:self.contextGestureRecognizerViewForDisabled];
}

-(void) setEnabled: (BOOL) enabled {
    [super setEnabled: enabled];
    self.contextGestureRecognizerViewForDisabled.userInteractionEnabled = !enabled;
}

-(UIView*) hitTest: (CGPoint) point withEvent: (UIEvent*) event {
    return self.enabled ? [super hitTest: point withEvent: event] : [self.contextGestureRecognizerViewForDisabled hitTest: point withEvent: event];
}

- (BOOL) canPerformAction: (SEL) action withSender: (id) sender {
    return self.enabled ? [super canPerformAction:action withSender: sender] : action == @selector(copy:);
}

- (void) copy: (id) sender {
    if (self.enabled) {
        [super copy: sender];
    } else {
        [UIPasteboard generalPasteboard].string = self.text;
    }
}


@end