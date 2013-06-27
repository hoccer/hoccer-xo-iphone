//
//  HXOActionSheet.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOSheetView.h"

static const CGFloat kHXOASHPadding = 20;
static const CGFloat kHXOASVPadding = 10;

@interface GradientSheetView : UIView
{
    HXOSheetStyle _style;
}

- (id) initWithFrame:(CGRect)frame style:(HXOSheetStyle) style;

@end

@implementation HXOSheetView

- (id) initWithTitle: (NSString*) title {
    self = [super init];
    if (self != nil) {
        _title = title;
        _sheetStyle = HXOSheetStyleAutomatic;
    }
    return self;
}

- (void)showInView:(UIView *)view {
    if (_sheetStyle == HXOSheetStyleAutomatic) {
        _sheetStyle = HXOSheetStyleDefault;
    }
    UIView * rootView = view.window.rootViewController.view;
    [rootView addSubview: self];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.frame = rootView.bounds;

    _coverView = [[UIView alloc] initWithFrame: rootView.bounds];
    _coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _coverView.backgroundColor = [UIColor blackColor];
    _coverView.alpha = 0;
    [self addSubview: _coverView];


    CGRect frame = rootView.bounds;
    frame.size.height = 150;
    frame.origin.y += rootView.bounds.size.height;
    _actionView = [[GradientSheetView alloc] initWithFrame: frame style: self.sheetStyle];
    //_actionView.backgroundColor = [UIColor clearColor];
    _actionView.opaque = NO;
    [self addSubview: _actionView];

    _titleLabel = [self createTitleLabel/*OfWidth: rootView.bounds.size.width*/];
    [_actionView addSubview: _titleLabel];

    [UIView animateWithDuration: 0.3 animations:^{
        _coverView.alpha = 0.5;
        CGRect frame = _actionView.frame;
        frame.origin.y -= frame.size.height;
        _actionView.frame = frame;
    }];
}

- (UILabel*) createTitleLabel/*OfWidth: (CGFloat) width*/ {
/*
    CGRect frame;
    frame.origin.x = kHXOASHPadding;
    frame.origin.y = kHXOASVPadding;
    CGFloat maxWidth = frame.size.width = width - 2 * kHXOASHPadding;
 */
    UILabel * label = [[UILabel alloc] initWithFrame: CGRectZero/*frame*/];
    label.textColor = [UIColor whiteColor];
    label.text = self.title;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor /*orangeColor*/ clearColor];
    label.textAlignment = NSTextAlignmentCenter;
/*
    [label sizeToFit];
    if (label.frame.size.width < maxWidth) {
        frame.size = label.frame.size;
        frame.origin.x = 0.5 * (width - label.frame.size.width);
        label.frame = frame;
    }
 */
    return label;
}

- (void) setTitle:(NSString *)title {
    _title = title;
    [self setNeedsLayout];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGRect frame;
    frame.origin.x = kHXOASHPadding;
    frame.origin.y = kHXOASVPadding;
    CGFloat maxWidth = frame.size.width = self.bounds.size.width - 2 * kHXOASHPadding;
    _titleLabel.text = _title;
    _titleLabel.frame = frame;
    [_titleLabel sizeToFit];
    if (_titleLabel.frame.size.width < maxWidth) {
        frame.size = _titleLabel.frame.size;
        frame.origin.x = 0.5 * (self.bounds.size.width - _titleLabel.frame.size.width);
        _titleLabel.frame = frame;
    }

    //_coverView.frame = self.window.rootViewController.view.bounds;
}

@end

@implementation GradientSheetView

- (id) initWithFrame:(CGRect)frame style: (HXOSheetStyle) style {
    self = [super initWithFrame: frame];
    if (self != nil) {
        self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        _style = style;
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    //[super drawRect: rect];

    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGGradientRef blackTranslucent = [self gradient];

    CGContextSaveGState(context);
    CGContextDrawLinearGradient(context, blackTranslucent, CGPointMake(93, 0), CGPointMake(93, 50), kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(context);    
    
    //// Cleanup
    CGGradientRelease(blackTranslucent);
}

- (CGGradientRef) gradient {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    
    //// Color Declarations
    UIColor* gradientColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.6];
    UIColor* gradientColor2 = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.6];

    //// Gradient Declarations
    NSArray* blackTranslucentColors = [NSArray arrayWithObjects:
                                       (id)gradientColor2.CGColor,
                                       (id)[UIColor colorWithRed: 0.5 green: 0.5 blue: 0.5 alpha: 0.6].CGColor,
                                       (id)gradientColor.CGColor, nil];
    CGFloat blackTranslucentLocations[] = {0, 0.12, 1};

    CGGradientRef blackTranslucent = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)blackTranslucentColors, blackTranslucentLocations);

    CGColorSpaceRelease(colorSpace);

    return blackTranslucent;
}

@end
