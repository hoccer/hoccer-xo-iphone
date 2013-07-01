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
static const CGFloat kHXOASAnimationDuration = 0.3;

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


    _actionView = [[GradientSheetView alloc] initWithFrame: rootView.bounds style: self.sheetStyle];
    _actionView.opaque = NO;
    [self addSubview: _actionView];

    _titleLabel = [self createTitleLabel];
    [_actionView addSubview: _titleLabel];
    [self layoutTitleLabel];

    // TODO: duplicate with layoutActionSheet
    CGRect frame = rootView.bounds;
    CGFloat height = [self controlSize: [self maxControlSize]].height;
    frame.size.height = height + _titleLabel.frame.origin.y + _titleLabel.frame.size.height + 3 * kHXOASVPadding;
    frame.origin.y = rootView.bounds.size.height;
    _actionView.frame = frame;
    
    [UIView animateWithDuration: kHXOASAnimationDuration animations:^{
        _coverView.alpha = 0.5;
        CGRect frame = _actionView.frame;
        frame.origin.y -= frame.size.height;
        _actionView.frame = frame;
    }];
}

- (UILabel*) createTitleLabel/*OfWidth: (CGFloat) width*/ {
    UILabel * label = [[UILabel alloc] initWithFrame: CGRectZero/*frame*/];
    label.textColor = [UIColor whiteColor];
    label.text = self.title;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor /*orangeColor*/ clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize: 14];
    label.shadowColor = [UIColor blackColor];
    label.shadowOffset = CGSizeMake(0, -1);
    return label;
}

- (void) setTitle:(NSString *)title {
    _title = title;
    [self setNeedsLayout];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self layoutTitleLabel];
    [self layoutActionView];
    CGRect controlFrame;
    controlFrame.origin.x = kHXOASHPadding;
    controlFrame.origin.y = _titleLabel.frame.origin.y + _titleLabel.frame.size.height + kHXOASVPadding;
    controlFrame.size = [self maxControlSize];
    [self layoutControls: _actionView maxFrame: controlFrame];
}

- (void) layoutActionView {
    UIView * rootView = self.window.rootViewController.view;
    CGRect frame = rootView.bounds;
    CGFloat height = [self controlSize: [self maxControlSize]].height;
    height = height + _titleLabel.frame.origin.y + _titleLabel.frame.size.height + 3 * kHXOASVPadding;
    if (height != frame.size.height) {
        frame.size.height = height;
        frame.origin.y = rootView.bounds.size.height - frame.size.height;
    }
    _actionView.frame = frame;
}

- (void) layoutTitleLabel {
    CGRect frame;
    frame.origin.x = kHXOASHPadding;
    frame.origin.y = kHXOASVPadding;
    CGFloat maxWidth = frame.size.width = self.bounds.size.width - 2 * kHXOASHPadding;
    frame.size.height = 0;
    _titleLabel.text = _title;
    _titleLabel.frame = frame;
    [_titleLabel sizeToFit];
    if (_titleLabel.frame.size.width < maxWidth) {
        frame.size = _titleLabel.frame.size;
        frame.origin.x = 0.5 * (self.bounds.size.width - _titleLabel.frame.size.width);
        _titleLabel.frame = frame;
    }
}

- (CGSize) maxControlSize {
    return CGSizeMake(self.bounds.size.width - 2 * kHXOASHPadding,
                      self.bounds.size.height - (_titleLabel.frame.origin.y + _titleLabel.frame.size.height + 3 * kHXOASVPadding));
}

- (CGFloat) layoutControls: (UIView*) container maxFrame:(CGRect) maxFrame {
    return 0;
}

- (CGSize)  controlSize: (CGSize) size {
    return CGSizeZero;
}

- (void) dismissAnimated: (BOOL) animated completion: (void(^)()) completion {
    void(^done)(void) = ^() {
        [self removeFromSuperview];
        completion();
    };
    if (animated) {
        [UIView animateWithDuration: kHXOASAnimationDuration animations:^{
            _coverView.alpha = 0.0;
            CGRect frame = _actionView.frame;
            frame.origin.y = self.bounds.size.height;
            _actionView.frame = frame;
        } completion:^(BOOL finished) {
            done();
        }];
    } else {
        done();
    }
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

    [self drawSeparatorAtY: 0.5 withColor: [UIColor blackColor]];
    [self drawSeparatorAtY: 1.5 withColor: [UIColor colorWithWhite: 0.6 alpha: 1.0]];

    //// Cleanup
    CGGradientRelease(blackTranslucent);
}

- (void) drawSeparatorAtY: (CGFloat) y withColor: (UIColor*) color {
    UIBezierPath* bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint: CGPointMake(0, y)];
    [bezierPath addLineToPoint: CGPointMake(self.bounds.size.width, y)];
    [color setStroke];
    bezierPath.lineWidth = 1;
    [bezierPath stroke];
}

- (CGGradientRef) gradient {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    
    //// Color Declarations
    UIColor* gradientColor0;
    UIColor* gradientColor1;
    UIColor* gradientColor2;

    CGFloat alpha = _style == HXOSheetStyleBlackTranslucent ? 0.75 : 1.0;
    switch (_style) {
        case HXOSheetStyleBlackTranslucent:
        case HXOSheetStyleBlackOpaque:
            gradientColor0 = [UIColor colorWithRed: 0.5 green: 0.5 blue: 0.5 alpha: alpha];
            gradientColor1 = [UIColor colorWithRed: 0.3 green: 0.3 blue: 0.3 alpha: alpha];
            gradientColor2 = [UIColor colorWithRed: 0.0 green: 0.0 blue: 0.0 alpha: alpha];
            break;
        case HXOSheetStyleDefault:
        default:
            gradientColor0 = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: alpha];
            gradientColor1 = [UIColor colorWithRed: 0.789 green: 0.794 blue: 0.864 alpha: alpha];
            gradientColor2 = [UIColor colorWithRed: 0.577 green: 0.588 blue: 0.729 alpha: alpha];
            break;
    }


    //// Gradient Declarations
    NSArray* colors = @[(id)gradientColor0.CGColor,
                        (id)gradientColor1.CGColor,
                        (id)gradientColor2.CGColor];
    CGFloat locations[] = {0, 0.3, 1};

    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);

    CGColorSpaceRelease(colorSpace);

    return gradient;
}

@end
