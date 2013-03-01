//
//  AutosizeLabel.m
//  ChatSpike
//
//  Created by David Siegel on 06.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AutoheightLabel.h"
#import <QuartzCore/QuartzCore.h>


//TODO: move bubble code in a separate view, because bubbles may also contain attachments

@interface AutoheightLabel ()

- (void)updateSize;

@end

@implementation AutoheightLabel

- (void) awakeFromNib {
    self.minHeight = self.bounds.size.height;
    self.arrowWidth = 15.0;
    self.arrowHCenter = self.minHeight * 0.5;
    self.arrowHeight = 2 * self.arrowWidth;
    self.arrowLeft = NO;
    self.layer.masksToBounds = YES;
}

- (CGSize) calculateSize: (NSString*) text {
    CGSize constraint = CGSizeMake(self.frame.size.width - self.arrowWidth, 20000.0f);
    return [text sizeWithFont:self.font constrainedToSize: constraint lineBreakMode: NSLineBreakByWordWrapping];
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

- (void) drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(context, YES);

    [[UIColor whiteColor] set];
    [self bubblePathInRect: rect context: context];
    CGContextFillPath(context);

    [[UIColor darkGrayColor] set];
    CGContextSetLineWidth(context, 1.0);
    [self bubblePathInRect: rect context: context];
    CGContextStrokePath(context);

    [super drawRect: rect];
}


- (void) bubblePathInRect: (CGRect) rect context: (CGContextRef) context {
    rect = CGRectMake(rect.origin.x + 0.5 + (self.arrowLeft ? self.arrowWidth : 0),
                      rect.origin.y + 0.5,
                      rect.size.width - self.arrowWidth - 1, rect.size.height - 1);
    CGFloat radius = 4.0;

    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);

    if (self.arrowLeft == YES) {
        [self addLeftArrow: rect context: context];
    }

    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius,
                    radius, M_PI, M_PI / 2, 1); //STS fixed
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius,
                            rect.origin.y + rect.size.height);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius,
                    rect.origin.y + rect.size.height - radius, radius, M_PI / 2, 0.0f, 1);

    if (self.arrowLeft == NO) {
        [self addRightArrow: rect context: context];
    }
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + radius);
    CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + radius,
                    radius, 0.0f, -M_PI / 2, 1);
    CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
    CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius,
                    -M_PI / 2, M_PI, 1);
}

- (void) addRightArrow: (CGRect) rect context: (CGContextRef) context {
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, self.arrowHCenter + self.arrowWidth);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width + self.arrowWidth, self.arrowHCenter);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, self.arrowHCenter - self.arrowWidth);
}

- (void) addLeftArrow: (CGRect) rect context: (CGContextRef) context {
    CGContextAddLineToPoint(context, rect.origin.x, self.arrowHCenter - self.arrowWidth);
    CGContextAddLineToPoint(context, rect.origin.x - self.arrowWidth, self.arrowHCenter);
    CGContextAddLineToPoint(context, rect.origin.x, self.arrowHCenter + self.arrowWidth);
}


- (void)drawTextInRect:(CGRect)rect {
    UIEdgeInsets insets = {5, 5 + (self.arrowLeft ? self.arrowWidth : 0), 5, 5 + (self.arrowLeft ? 0 : self.arrowWidth)};
    return [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

@end
