//
//  UIButton+GlossyRounded.m
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//


// Inspired by https://github.com/GeorgeMcMullen/UIButton-Glossy but still needs some tweaking

#import "UIButton+GlossyRounded.h"
#import <QuartzCore/QuartzCore.h>

void UIButton_GlossyRounded_touch()
{
    NSLog(@"Do nothing, just to make categories link correctly for static files.");
}

@implementation UIButton (GlossyRounded)

- (void) makeRoundAndGlossy {
    CALayer *thisLayer = self.layer;
    
    // Add a border
    thisLayer.cornerRadius = 0.5 * self.frame.size.height;
    thisLayer.masksToBounds = NO;
    thisLayer.borderWidth = 1.0f;
    thisLayer.borderColor = [[UIColor colorWithWhite: 0.0 alpha: 0.8] CGColor];

    // Give it a shadow
    if ([thisLayer respondsToSelector:@selector(shadowOpacity)]) // For compatibility, check if shadow is supported
    {
        thisLayer.shadowOpacity = 1.0;
        thisLayer.shadowColor = [[UIColor whiteColor] CGColor];
        thisLayer.shadowOffset = CGSizeMake(0.0, 1.0);
        thisLayer.shadowRadius = 0.0;
        
        // TODO: Need to test these on iPad
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2)
        {
            thisLayer.rasterizationScale=2.0;
        }
        thisLayer.shouldRasterize = YES; // FYI: Shadows have a poor effect on performance
    }
    
    // Add backgorund color layer and make original background clear
    CALayer *backgroundLayer = [CALayer layer];
    backgroundLayer.cornerRadius = thisLayer.cornerRadius;
    backgroundLayer.masksToBounds = YES;
    backgroundLayer.frame = thisLayer.bounds;
    backgroundLayer.backgroundColor=self.backgroundColor.CGColor;
    [thisLayer insertSublayer:backgroundLayer atIndex:0];
    
    thisLayer.backgroundColor=[UIColor colorWithWhite:0.0f alpha:0.0f].CGColor;
    
    // Add gloss to the background layer
    CAGradientLayer *glossLayer = [CAGradientLayer layer];
    glossLayer.frame = thisLayer.bounds;
    glossLayer.colors = [NSArray arrayWithObjects:
                         (id)[UIColor colorWithWhite:1.0f alpha:0.4f].CGColor,
                         (id)[UIColor colorWithWhite:1.0f alpha:0.2f].CGColor,
                         (id)[UIColor colorWithWhite:0.75f alpha:0.0f].CGColor,
                         (id)[UIColor colorWithWhite:1.0f alpha:0.2f].CGColor,
                         nil];
    glossLayer.locations = [NSArray arrayWithObjects:
                            [NSNumber numberWithFloat:0.0f],
                            [NSNumber numberWithFloat:0.5f],
                            [NSNumber numberWithFloat:0.5f],
                            [NSNumber numberWithFloat:1.0f],
                            nil];
    [backgroundLayer addSublayer:glossLayer];
}

@end
