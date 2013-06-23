//
//  ShadowedTableView.m
//  HoccerXO
//
//  Created by David Siegel on 19.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ShadowedTableView.h"

#import <QuartzCore/QuartzCore.h>

#import "RadialGradientView.h"

static const CGFloat kHXOTableTopShadowHeight = 10;
static const CGFloat kHXOTableBottomShadowHeight = 20;
static const CGFloat kHXOGroupedTableCanvasBottomPadding = 30;


@interface GradientLayerDelegate : NSObject

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;

@end


@interface ShadowedTableView ()

@property (nonatomic,strong) CALayer * bottomTerminator;
@property (nonatomic,strong) CALayer * cellCanvas;
@property (nonatomic,strong) GradientLayerDelegate * gradientDelegate;

@end


@implementation ShadowedTableView

- (void) layoutSubviews {
    BOOL isGrouped = self.style == UITableViewStyleGrouped;
    if (self.cellCanvas == nil) {
        self.cellCanvas = [CALayer layer];
        self.cellCanvas.backgroundColor = (isGrouped ? [UIColor orangeColor] : [UIColor blackColor]).CGColor;
        self.cellCanvas.shadowColor = [UIColor blackColor].CGColor;
        self.cellCanvas.shadowRadius = 20;
        self.cellCanvas.shadowOpacity = 1.0;
        self.cellCanvas.shadowOffset = CGSizeMake(0, 5);
        self.cellCanvas.shouldRasterize = YES;
        self.gradientDelegate = [[GradientLayerDelegate alloc] init];
        if (isGrouped) {
            self.cellCanvas.delegate = self.gradientDelegate;
            self.cellCanvas.needsDisplayOnBoundsChange = YES;
        }
    }

    if ([self.layer.sublayers containsObject: self.cellCanvas]) {
        [self.cellCanvas removeFromSuperlayer];
    }
    [self.layer insertSublayer: self.cellCanvas atIndex: 0];

    // Creative way to get the content height. Using self.contentSize does not work
    // beacuse if the table has a header (e.g. a searchbar) the size is always
    // at least the sreen size.
    NSUInteger lastSection = [self numberOfSections] - 1;
    NSIndexPath * lastRow = [NSIndexPath indexPathForItem: [self numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
    CGRect lastCellRect = [self rectForRowAtIndexPath: lastRow];

    CGRect frame;
    frame.origin = CGPointMake(0, 0);
    frame.size = CGSizeMake(self.contentSize.width, lastCellRect.origin.y + lastCellRect.size.height);
    if (self.showBottomTerminator) {
        UIImage * bottomTerminatorImage = [UIImage imageNamed:@"table_view_bottom_terminator"];
        if (self.bottomTerminator == nil) {
            self.bottomTerminator = [CALayer layer];
            self.bottomTerminator.contents = (id)bottomTerminatorImage.CGImage;
            [self.cellCanvas addSublayer: self.bottomTerminator];
        }
        CGRect terminatorFrame = CGRectMake(0, frame.size.height, frame.size.width, bottomTerminatorImage.size.height);
        self.bottomTerminator.frame= terminatorFrame;
        frame.size.height += bottomTerminatorImage.size.height;
    } else if (isGrouped) {
        frame.size.height += kHXOGroupedTableCanvasBottomPadding;
    }

    self.cellCanvas.frame = frame;

    // Call super class late. Otherwise new cells are hidden behind the canvas layer.
    // I'm not sure why this happens...
    [super layoutSubviews];
}

@end

@implementation GradientLayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    CGSize size = layer.frame.size;
    CGPoint center = CGPointMake(0.5 * size.width, 0.33 * size.height);
    [RadialGradientView drawInContext: ctx withSize: size andCenter: center];
}

@end
