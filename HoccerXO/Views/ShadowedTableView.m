//
//  ShadowedTableView.m
//  HoccerXO
//
//  Created by David Siegel on 19.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ShadowedTableView.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kHXOTableTopShadowHeight = 10;
static const CGFloat kHXOTableBottomShadowHeight = 20;



@interface ShadowedTableView ()

@property (nonatomic,strong) CALayer * topShadow;
@property (nonatomic,strong) CALayer * bottomShadow;

@end

@implementation ShadowedTableView

- (void) layoutSubviews {
    [super layoutSubviews];

    NSArray * visibleRows = [self indexPathsForVisibleRows];

    if (visibleRows.count == 0) {
        [self.topShadow removeFromSuperlayer];
        self.topShadow = nil;

        [self.bottomShadow removeFromSuperlayer];
        self.bottomShadow = nil;
        return;
    }

    NSIndexPath * firstRow = visibleRows[0];
    if (firstRow.section == 0 && firstRow.row == 0) {
        UITableViewCell * cell = [self cellForRowAtIndexPath: firstRow];
        if (self.topShadow == nil) {
            self.topShadow = [self pseudoShadowWithHeight: kHXOTableTopShadowHeight isFlipped: YES];
        }
        if ( ! [cell.layer.sublayers containsObject: self.topShadow]) {
            [cell.layer addSublayer: self.topShadow];
        }
        CGRect shadowFrame = self.topShadow.frame;
		shadowFrame.size.width = cell.frame.size.width;
		shadowFrame.origin.y = - kHXOTableTopShadowHeight;
		self.topShadow.frame = shadowFrame;
    } else {
        [self.topShadow removeFromSuperlayer];
        self.topShadow = nil;
    }

    NSIndexPath * lastRow = [visibleRows lastObject];
    if (lastRow.section == [self numberOfSections] - 1 && lastRow.row == [self numberOfRowsInSection: lastRow.section] - 1) {
        UITableViewCell * cell = [self cellForRowAtIndexPath: lastRow];
        if (self.bottomShadow == nil) {
            self.bottomShadow = [self pseudoShadowWithHeight: kHXOTableBottomShadowHeight isFlipped: NO];
        }
        if ( ! [cell.layer.sublayers containsObject: self.bottomShadow]) {
            [cell.layer addSublayer: self.bottomShadow];
        }
        CGRect shadowFrame = self.bottomShadow.frame;
		shadowFrame.size.width = cell.frame.size.width;
		shadowFrame.origin.y = cell.frame.size.height;
		self.bottomShadow.frame = shadowFrame;
    } else {
        [self.bottomShadow removeFromSuperlayer];
        self.bottomShadow = nil;
    }
}

- (CALayer*) pseudoShadowWithHeight: (CGFloat) height isFlipped: (BOOL) flipped {
    CAGradientLayer *shadow = [CAGradientLayer layer];    
    shadow.frame = CGRectMake(0, 0, self.frame.size.width, height);
    CGColorRef darkColor = [UIColor colorWithWhite: 0 alpha: flipped ? 0.2 : 0.5].CGColor;
    CGColorRef lightColor = [UIColor clearColor].CGColor;
    
    shadow.colors = @[(__bridge id)(flipped ? lightColor : darkColor), (__bridge id)(flipped ? darkColor : lightColor)];
    return shadow;
}

@end
