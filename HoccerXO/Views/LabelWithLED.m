//
//  NickNameLabelWithStatus.m
//  HoccerXO
//
//  Created by David Siegel on 29.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "LabelWithLED.h"

static const CGFloat kLEDPadding = 2.0;
static const CGFloat kLEDSize = 5.0;

@interface LabelWithLED ()

@property (nonatomic,strong) CALayer * ledLayer;

@end

@implementation LabelWithLED
{
    BOOL _isInitializing;
}
@synthesize ledColor = _ledColor;

- (id) init {
    _isInitializing = YES;
    self = [super init];
    if (self) {
        [self commonInit];
    }
    _isInitializing = NO;
    return self;
}

- (id)initWithFrame: (CGRect) frame {
    _isInitializing = YES;
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    _isInitializing = NO;
    return self;
}

- (id)initWithCoder: (NSCoder*) aDecoder {
    _isInitializing = YES;
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    _isInitializing = NO;
    return self;
}

- (void) commonInit {
    _ledColor = [UIColor redColor];
    
    self.ledLayer = [CALayer layer];
    self.ledLayer.cornerRadius = 0.5 * kLEDSize;
    self.ledLayer.bounds = CGRectMake(0,0,kLEDSize,kLEDSize);
    self.ledLayer.backgroundColor = _ledColor.CGColor;
    [self.layer addSublayer: self.ledLayer];
    self.ledLayer.opacity = 0;
}

- (CGSize) intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    s.width += [self ledSpace];
    return s;
}

- (CGFloat) ledSpace {
    CGFloat totalSize = kLEDPadding + kLEDSize;
    return self.textAlignment == NSTextAlignmentCenter ? 2 * totalSize : totalSize;
}

- (void) setLedOn: (BOOL) ledOn {
    _ledOn = ledOn;
    self.ledLayer.opacity = ledOn ? 1.0 : 0.0;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    // TODO: compute proper position
    self.ledLayer.position = CGPointMake(self.bounds.size.width - kLEDSize, 0.5 * self.bounds.size.height);
}

- (void) setLedColor:(UIColor *)ledColor {
    _ledColor = ledColor;
    self.ledLayer.backgroundColor = ledColor.CGColor;
}

- (UIColor*) ledColor {
    return _ledColor;
}

@end
