//
//  NickNameLabelWithStatus.m
//  HoccerXO
//
//  Created by David Siegel on 29.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NickNameLabelWithStatus.h"

static const CGFloat kLEDPadding = 2.0;
static const CGFloat kLEDSize = 5.0;

@interface NickNameLabelWithStatus ()

@property (nonatomic,strong) CALayer * ledLayer;
@property (nonatomic,readonly) UILabel * label;

@end

@implementation NickNameLabelWithStatus

- (id) init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
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
    self.ledLayer.anchorPoint = CGPointMake(0, 0.4);
    [self.layer addSublayer: self.ledLayer];
    self.ledLayer.opacity = 0;

    _label = [[UILabel alloc] initWithFrame: self.bounds];
    [self addSubview: self.label];
    _label.numberOfLines = 1;
}

- (CGSize) sizeThatFits:(CGSize)size {
    size = [self.label sizeThatFits: size];
    size.width += [self ledSpace];
    return size;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self.label sizeToFit];
    CGRect frame = self.label.frame;
    frame.origin.x = self.label.textAlignment == NSTextAlignmentCenter ? kLEDPadding + kLEDSize : 0;
    self.label.frame = frame;
    self.ledLayer.position = CGPointMake(frame.origin.x + frame.size.width + kLEDPadding, 0.5 * frame.size.height);

}
- (CGFloat) ledSpace {
    CGFloat totalSize = kLEDPadding + kLEDSize;
    return self.label.textAlignment == NSTextAlignmentCenter ? 2 * totalSize : totalSize;
}

- (void) setIsOnline:(BOOL)isOnline {
    _isOnline = isOnline;
    self.ledLayer.opacity = isOnline ? 1.0 : 0.0;
}

- (void) setText:(NSString *)text {
    self.label.text = text;
    [self setNeedsLayout];
}

- (NSString*) text {
    return self.label.text;
}

- (void) setTextAlignment:(NSTextAlignment)textAlignment {
    self.label.textAlignment = textAlignment;
    [self setNeedsLayout];
}

- (NSTextAlignment) textAlignment {
    return self.label.textAlignment;
}

- (void) setFont:(UIFont *)font {
    self.label.font = font;
    [self setNeedsLayout];
}

- (UIFont*) font {
    return self.label.font;
}

- (void) setTextColor:(UIColor *)textColor {
    self.label.textColor = textColor;
}

- (UIColor*) textColor {
    return self.label.textColor;
}

@end
