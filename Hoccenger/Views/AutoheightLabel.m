//
//  AutosizeLabel.m
//  ChatSpike
//
//  Created by David Siegel on 06.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AutoheightLabel.h"

#define MIN_HEIGHT 10

@interface AutoheightLabel ()

- (void)updateSize;

@end

@implementation AutoheightLabel

@synthesize minHeight;

- (id)init {
    if ([super init]) {
        self.minHeight = MIN_HEIGHT;
    }

    return self;
}

- (CGSize) calculateSize: (NSString*) text {
    CGSize constraint = CGSizeMake(self.frame.size.width, 20000.0f);
    return [text sizeWithFont:self.font constrainedToSize: constraint lineBreakMode: NSLineBreakByWordWrapping];
}

- (void)updateSize {
    CGSize size = [self calculateSize: self.text];

    [self setLineBreakMode: NSLineBreakByWordWrapping];
    [self setAdjustsFontSizeToFitWidth:NO];
    [self setNumberOfLines:0];
    [self setFrame:CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, MAX(size.height, minHeight))];

}

- (void)setText:(NSString *)text {
    [super setText:text];

    [self updateSize];
}

- (void)setFont:(UIFont *)font {
    [super setFont:font];

    [self updateSize];
}


@end
