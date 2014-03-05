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
    self.ledLayer = [CALayer layer];
    self.ledLayer.cornerRadius = 0.5 * kLEDSize;
    self.ledLayer.bounds = CGRectMake(0,0,kLEDSize,kLEDSize);
    self.ledLayer.backgroundColor = [UIColor redColor].CGColor;
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

@end
