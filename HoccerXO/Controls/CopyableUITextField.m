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

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    // Add the gesture recognizer
    self.contextGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureDidFire:)];
    [self addGestureRecognizer:self.contextGestureRecognizer];
    
    return self;
}

// First-level of response, filters out some noise
-(IBAction) longPressGestureDidFire:(id)sender {
    UILongPressGestureRecognizer *recognizer = sender;
    if(recognizer.state == UIGestureRecognizerStateBegan) { // Only fire once
        [self initiateContextMenu:sender];
    }
}

// Second level of response - actually trigger the menu
-(IBAction) initiateContextMenu:(id)sender {
    [self becomeFirstResponder]; // So the menu will be active.  We can't set the Text field to be first responder -- doesn't work if it is disabled
    UIMenuController *menu = [UIMenuController sharedMenuController];
    [menu setTargetRect:self.bounds inView:self];
    [menu setMenuVisible:YES animated:YES];
}

// The menu will automatically add a "Copy" command if it sees a "copy:" method.
// See UIResponderStandardEditActions to see what other commands we can add through methods.
-(IBAction) copy:(id)sender {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    UITextField *tf = (UITextField *)self.superview;
    [pb setString: tf.text];
}

// Normally a UIView doesn't want to become a first responder.  This forces the issue.
-(BOOL) canBecomeFirstResponder {
    return YES;
}

@end

@implementation CopyableUITextField
@synthesize contextGestureRecognizerViewForDisabled = _contextGestureRecognizerViewForDisabled;

/* Add the recognizer view no matter which path this is initialized through */

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self addDisabledRecognizer];
    return self;
}

-(id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [self addDisabledRecognizer];
    return self;
}

// This creates the view and adds it at the end of the view chain so it doesn't interfere, but is still present */
-(void) addDisabledRecognizer {
    self.contextGestureRecognizerViewForDisabled = [[CopyableUITextFieldResponderView alloc] initWithFrame:self.bounds];
    self.contextGestureRecognizerViewForDisabled.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contextGestureRecognizerViewForDisabled.userInteractionEnabled = NO;
    [self addSubview:self.contextGestureRecognizerViewForDisabled];
}

-(void) setEnabled:(BOOL) enabled {
    [super setEnabled:enabled];
    self.contextGestureRecognizerViewForDisabled.userInteractionEnabled = !enabled;
}

// This is where the magic happens
-(UIView *) hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.enabled) {
        // If we are enabled, respond normally
        return [super hitTest:point withEvent:event];
    } else {
        // If we are disabled, let our specialized view determine how to respond
        UIView *v = [self.contextGestureRecognizerViewForDisabled hitTest:point withEvent:event];
        return v;
    }
}

@end