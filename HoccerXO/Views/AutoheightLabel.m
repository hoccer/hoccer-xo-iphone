//
//  AutosizeLabel.m
//  ChatSpike
//
//  Created by David Siegel on 06.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AutoheightLabel.h"
#import <QuartzCore/QuartzCore.h>

// TODO: move bubble code to a separate view, because bubbles may also contain attachments
// TODO: add gradient

@interface AutoheightLabel ()

- (void)updateSize;

@end

@implementation AutoheightLabel

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        self.minHeight = self.bounds.size.height;
    }
    return self;
}

- (CGSize) calculateSize: (NSString*) text {
    CGSize constraint = CGSizeMake(self.frame.size.width, MAXFLOAT);
    CGSize size = [text sizeWithFont:self.font constrainedToSize: constraint lineBreakMode: NSLineBreakByWordWrapping];
    size.height = MAX(size.height, self.minHeight);
    return size;
}

- (void)updateSize {
    CGSize size = [self calculateSize: self.text];

    [self setLineBreakMode: NSLineBreakByWordWrapping];
    [self setAdjustsFontSizeToFitWidth:NO];
    [self setNumberOfLines:0];
    [self setFrame:CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, MAX(size.height, self.minHeight))];
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
