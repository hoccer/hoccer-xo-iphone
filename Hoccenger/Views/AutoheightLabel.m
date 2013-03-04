//
//  AutosizeLabel.m
//  ChatSpike
//
//  Created by David Siegel on 06.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AutoheightLabel.h"
#import <QuartzCore/QuartzCore.h>

#import "CornerRadius.h"


// TODO: move bubble code to a separate view, because bubbles may also contain attachments
// TODO: add gradient and shadow
// TODO: respect margins in text size computation

@interface AutoheightLabel ()

@property (nonatomic) double arrowHCenter;
@property (nonatomic) UIBezierPath* bubblePath;
@property (nonatomic) CAGradientLayer* gradientLayer;
@property (nonatomic) CAShapeLayer* shapeLayer;

- (void)updateSize;
- (void)createBubblePath;

@end

@implementation AutoheightLabel

- (void) awakeFromNib {
    self.minHeight = self.bounds.size.height;
    self.arrowWidth = 10.0;
    self.arrowHCenter = self.bounds.size.height * 0.5;

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.3f;
    self.layer.shadowOffset = CGSizeMake(2.0f, 2.0f);
    self.layer.shadowRadius = 3.0f;
    self.layer.masksToBounds = NO;

    self.gradientLayer = [self bubbleGradient];
    //[self.layer insertSublayer: self.gradientLayer atIndex: 0];
    self.shapeLayer = [CAShapeLayer layer];


    self.padding = UIEdgeInsetsMake(15, 15, 15, 15);
}

- (UIEdgeInsets) calculateTextRect {
    return UIEdgeInsetsMake(self.padding.top,
                            self.padding.left + (self.arrowLeft ? self.arrowWidth : 0),
                            self.padding.bottom,
                            self.padding.right + (self.arrowLeft ? 0 : self.arrowWidth));
}

- (CGSize) calculateSize: (NSString*) text {
    CGSize constraint = CGSizeMake(self.frame.size.width - (self.arrowWidth  + self.padding.left + self.padding.right), 20000.0f);
    CGSize size = [text sizeWithFont:self.font constrainedToSize: constraint lineBreakMode: NSLineBreakByWordWrapping];
    size.height += self.padding.top + self.padding.bottom;
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

- (void) layoutSubviews {
    [super layoutSubviews];
    [self createBubblePath];
    self.gradientLayer.frame = self.bounds;
    self.shapeLayer.path = self.bubblePath.CGPath;

    self.gradientLayer.mask = self.shapeLayer;

}

- (void) setArrowLeft:(BOOL)arrowLeft {
    _arrowLeft = arrowLeft;
    [self createBubblePath];
}

- (void) drawRect:(CGRect)rect {
    [self.bubbleColor set];
    [self.bubblePath fill];

    [[UIColor colorWithWhite: 0.0 alpha: 0.5] set];
    [self.bubblePath stroke];
    
    /*
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(context, YES);

    [[UIColor whiteColor] set];
    [self bubblePathInRect: rect context: context];
    CGContextFillPath(context);

    UIColor * start = [UIColor colorWithWhite: 0.0 alpha: 0.0];
    UIColor * end = [UIColor colorWithWhite: 0.0 alpha: 0.1];

    [self bubblePathInRect: rect context: context];
    drawLinearGradient(context, rect, start.CGColor, end.CGColor);

    [[UIColor darkGrayColor] set];
    CGContextSetLineWidth(context, 1.0);
    [self bubblePathInRect: rect context: context];
    CGContextStrokePath(context);
     */

    [super drawRect: rect];
}

- (void) createBubblePath {
    CGRect rect = CGRectMake(self.bounds.origin.x + 0.5 + (self.arrowLeft ? self.arrowWidth : 0),
                      self.bounds.origin.y + 0.5,
                      self.bounds.size.width - self.arrowWidth - 1, self.bounds.size.height - 1);

    UIBezierPath * path = [[UIBezierPath alloc] init];
    [path moveToPoint: CGPointMake(rect.origin.x, rect.origin.y + kCornerRadius)];

    if (self.arrowLeft == YES) {
        // TODO: add arc
        [path addLineToPoint: CGPointMake(rect.origin.x, self.arrowHCenter - self.arrowWidth)];
        [path addLineToPoint: CGPointMake(rect.origin.x - self.arrowWidth, self.arrowHCenter)];
        [path addLineToPoint: CGPointMake(rect.origin.x, self.arrowHCenter + self.arrowWidth)];
        // TODO: add arc
    }

    [path addLineToPoint: CGPointMake(rect.origin.x, rect.origin.y + rect.size.height - kCornerRadius)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + kCornerRadius, rect.origin.y + rect.size.height - kCornerRadius)
                    radius: kCornerRadius startAngle: M_PI endAngle: M_PI / 2 clockwise: NO];
    [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width - kCornerRadius, rect.origin.y + rect.size.height)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + rect.size.width - kCornerRadius, rect.origin.y + rect.size.height - kCornerRadius)
                    radius: kCornerRadius startAngle: M_PI / 2 endAngle: 0.0 clockwise: NO];

    if (self.arrowLeft == NO) {
        // TODO: add arc
        [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, self.arrowHCenter + self.arrowWidth)];
        [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width + self.arrowWidth, self.arrowHCenter)];
        [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, self.arrowHCenter - self.arrowWidth)];
        // TODO: add arc
    }

    [path addLineToPoint: CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + kCornerRadius)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + rect.size.width - kCornerRadius, rect.origin.y + kCornerRadius)
                    radius: kCornerRadius startAngle: 0.0 endAngle: -M_PI / 2 clockwise: NO];
    [path addLineToPoint: CGPointMake(rect.origin.x + kCornerRadius, rect.origin.y)];
    [path addArcWithCenter: CGPointMake(rect.origin.x + kCornerRadius, rect.origin.y + kCornerRadius)
                    radius: kCornerRadius startAngle: -M_PI / 2 endAngle: M_PI clockwise: NO];

    self.bubblePath = path;
    self.layer.shadowPath = path.CGPath;
}

- (CAGradientLayer*) bubbleGradient {
    UIColor *colorOne = [UIColor colorWithWhite:0.9 alpha:1.0];
    UIColor *colorTwo = [UIColor colorWithHue:0.625 saturation:0.0 brightness:0.85 alpha:1.0];
    UIColor *colorThree     = [UIColor colorWithHue:0.625 saturation:0.0 brightness:0.7 alpha:1.0];
    UIColor *colorFour = [UIColor colorWithHue:0.625 saturation:0.0 brightness:0.4 alpha:1.0];
    
    NSArray *colors =  @[(id)colorOne.CGColor, (id)colorTwo.CGColor, (id)colorThree.CGColor, (id)colorFour.CGColor];

    NSNumber *stopOne = [NSNumber numberWithFloat:0.0];
    NSNumber *stopTwo = [NSNumber numberWithFloat:0.02];
    NSNumber *stopThree     = [NSNumber numberWithFloat:0.99];
    NSNumber *stopFour = [NSNumber numberWithFloat:1.0];

    NSArray *locations = [NSArray arrayWithObjects:stopOne, stopTwo, stopThree, stopFour, nil];
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.colors = colors;
    layer.locations = locations;

    return layer;
}


void drawLinearGradient(CGContextRef context, CGRect rect, CGColorRef startColor,
                        CGColorRef  endColor) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };

    NSArray *colors = @[(__bridge id)startColor, (__bridge id)endColor];

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)(colors), locations);
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect) - 10);
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));

    CGContextSaveGState(context);
    //CGContextAddRect(context, rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

//- (CGRect) textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines

- (void)drawTextInRect:(CGRect)rect {
    UIEdgeInsets insets = UIEdgeInsetsMake(self.padding.top,
                                           self.padding.left + (self.arrowLeft ? self.arrowWidth : 0),
                                           self.padding.bottom,
                                           self.padding.right + (self.arrowLeft ? 0 : self.arrowWidth));
    return [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

@end
