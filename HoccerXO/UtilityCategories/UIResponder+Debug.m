//
//  UIResponder+Debug.m
//  HoccerXO
//
//  Created by PM on 20.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UIResponder+Debug.h"

@implementation UIView (NBResponderChainUtilities)
- (UIView*) nb_firstResponder
    {
        if ([self isFirstResponder]){
            return self;
        }
        for (UIView *subView in self.subviews)
        {
            UIView *firstResponder = [subView nb_firstResponder];
            if (firstResponder != nil)
            {
                return firstResponder;
            }
        }
        return nil;
    }
    @end

@implementation UIApplication (NBResponderChainUtilities)
- (UIView*) nb_firstResponder
    {
        return [[self keyWindow] nb_firstResponder];
    }
    @end

@implementation UIResponder (NBResponderChainUtilities)
- (NSArray*) nb_responderChain
    {
        return [@[self] arrayByAddingObjectsFromArray:[self.nextResponder nb_responderChain]];
    }
    @end

UIView * NBFirstResponder(void)
{
    return [[UIApplication sharedApplication] nb_firstResponder];
}

NSArray * NBResponderChain(void)
{
    return [NBFirstResponder() nb_responderChain];
}

