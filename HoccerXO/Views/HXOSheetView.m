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

@interface ActionView : UIView

@end

@implementation HXOSheetView

- (id) initWithTitle: (NSString*) title {
    self = [super init];
    if (self != nil) {
        self.title = title;
    }
    return self;
}

- (void)showInView:(UIView *)view {
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
    _actionView = [[ActionView alloc] initWithFrame: frame];
    //_actionView.backgroundColor = [UIColor clearColor];
    _actionView.opaque = NO;
    [self addSubview: _actionView];

    UILabel * titleLabel = [self createTitleLabelOfWidth: rootView.bounds.size.width];
    [_actionView addSubview: titleLabel];

    [UIView animateWithDuration: 0.3 animations:^{
        _coverView.alpha = 0.5;
        CGRect frame = _actionView.frame;
        frame.origin.y -= frame.size.height;
        _actionView.frame = frame;
    }];
}

- (UILabel*) createTitleLabelOfWidth: (CGFloat) width {
    CGRect frame;
    frame.origin.x = kHXOASHPadding;
    frame.origin.y = kHXOASVPadding;
    CGFloat maxWidth = frame.size.width = width - 2 * kHXOASHPadding;
    UILabel * label = [[UILabel alloc] initWithFrame: frame];
    label.textColor = [UIColor whiteColor];
    label.text = self.title;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    if (label.frame.size.width < maxWidth) {
        frame.size = label.frame.size;
        frame.origin.x = 0.5 * (width - label.frame.size.width);
        label.frame = frame;
    }
    return label;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    //_coverView.frame = self.window.rootViewController.view.bounds;
}

@end

@implementation ActionView

- (void) drawRect:(CGRect)rect {
    //[super drawRect: rect];

    //// General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();

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

    CGContextSaveGState(context);
    CGContextDrawLinearGradient(context, blackTranslucent, CGPointMake(93, 0), CGPointMake(93, 50), kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(context);    
    
    //// Cleanup
    CGGradientRelease(blackTranslucent);
    CGColorSpaceRelease(colorSpace);

}

@end
