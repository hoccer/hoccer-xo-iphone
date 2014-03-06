//
//  NickNameLabelWithStatus.m
//  HoccerXO
//
//  Created by David Siegel on 29.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "LabelWithLED.h"

static const CGFloat kLEDPadding = 4.0;
static const CGFloat kLEDSize = 5.0;

@interface LabelWithLED ()

@property (nonatomic,strong) CALayer * ledLayer;

@end

@implementation LabelWithLED
@synthesize ledColor = _ledColor;

- (id) init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame: (CGRect) frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder: (NSCoder*) aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    _ledColor = [UIColor redColor];
    
    self.ledLayer = [CALayer layer];
    self.ledLayer.cornerRadius = 0.5 * kLEDSize;
    self.ledLayer.bounds = CGRectMake(0,0,kLEDSize,kLEDSize);
    self.ledLayer.backgroundColor = _ledColor.CGColor;
    self.ledLayer.opacity = 0;
    [self.layer addSublayer: self.ledLayer];
}

#pragma mark - Layout

- (CGSize) intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    s.width += [self ledSpace];
    return s;
}

- (CGSize) sizeThatFits:(CGSize)size {
    size = [super sizeThatFits:size];
    size.width += [self ledSpace];
    return size;
}

- (CGFloat) ledSpace {
    CGFloat totalSize = kLEDPadding + kLEDSize;
    return self.textAlignment == NSTextAlignmentCenter ? 2 * totalSize : totalSize;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    self.ledLayer.position = CGPointMake(self.bounds.size.width - kLEDSize, self.font.ascender - 0.5 * self.font.xHeight);
}

#pragma mark - LED State

- (void) setLedOn: (BOOL) ledOn {
    _ledOn = ledOn;
    self.ledLayer.opacity = ledOn ? 1.0 : 0.0;
}

- (void) setLedColor:(UIColor *)ledColor {
    _ledColor = ledColor;
    self.ledLayer.backgroundColor = ledColor.CGColor;
}

- (UIColor*) ledColor {
    return _ledColor;
}

@end
