//
//  UIResponder+Debug.h
//  HoccerXO
//
//  Created by PM on 20.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (NBResponderChainUtilities)
- (UIView*) nb_firstResponder; // Recurse into subviews to find one that responds YES to -isFirstResponder
    @end

@interface UIApplication (NBResponderChainUtilities)
- (UIView*) nb_firstResponder; // in the -keyWindow
    @end

@interface UIResponder (NBResponderChainUtilities)
- (NSArray*) nb_responderChain; // List the -nextResponder starting at the receiver
    @end


UIView * NBFirstResponder(void); // in the app key window
NSArray * NBResponderChain(void); // Starting at the first responder