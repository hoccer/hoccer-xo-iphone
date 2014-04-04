//
//  ProfileAvatarView.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AvatarView.h"

#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#import "VectorArt.h"
#import "GhostBustersSign.h"
#import "HXOUI.h"

static const CGFloat kBlockedSignPaddingOffset = 7.0 / 19;
static const CGFloat kBlockedSignPaddingFactor = 1.0 / 67;

static const CGFloat kBadgeFontSizeOffset = 84.0 / 19;
static const CGFloat kBadgeFontSizeFactor = 3.0 / 19;

static const CGFloat kBadgePaddingOffset = 15.0 / 19;
static const CGFloat kBadgePaddingFactor =  7.0 / 152;

@interface AvatarView ()

@property (nonatomic, strong) CALayer      * avatarLayer;
@property (nonatomic, strong) CAShapeLayer * defaultAvatarLayer;
@property (nonatomic, strong) CAShapeLayer * blockedSignLayer;
@property (nonatomic, strong) CATextLayer  * badgeLayer;

@end

@implementation AvatarView

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        self.opaque = NO;

        CGFloat size = MIN(frame.size.width, frame.size.height);

        self.avatarLayer = [CALayer layer];
        self.avatarLayer.backgroundColor = [HXOUI theme].defaultAvatarBackgroundColor.CGColor;
        self.avatarLayer.position = self.center;
        self.avatarLayer.bounds = CGRectMake(0, 0, size, size);
        self.avatarLayer.mask = [self maskLayer];
        [self.layer addSublayer: self.avatarLayer];

        self.defaultAvatarLayer = [CAShapeLayer layer];
        self.defaultAvatarLayer.bounds = self.avatarLayer.bounds;
        self.defaultAvatarLayer.mask = [self maskLayer];
        [self.layer addSublayer: self.defaultAvatarLayer];

        self.blockedSignLayer = [CAShapeLayer layer];
        CGFloat blockSignSize = size - [self blockedSignPadding];
        self.blockedSignLayer.bounds = CGRectMake(0, 0, blockSignSize, blockSignSize);
        [self.layer addSublayer: self.blockedSignLayer];
        self.blockedSignLayer.opacity = 0;

        self.blockedSign = [[GhostBustersSign alloc] init];

        self.badgeLayer = [CATextLayer layer];
        self.badgeLayer.bounds = CGRectMake(0,0,20,20);
        self.badgeLayer.backgroundColor = [UIColor redColor].CGColor;
        self.badgeLayer.contentsScale = [UIScreen mainScreen].scale;
        self.badgeLayer.alignmentMode = kCAAlignmentCenter;
        self.badgeLayer.anchorPoint = CGPointMake(1,0);
        self.badgeLayer.position = CGPointMake(CGRectGetMaxX(self.avatarLayer.bounds), self.padding);
        [self.layer addSublayer: self.badgeLayer];
        //[self setNeedsLayout];
    }
    return self;
}

- (void) setBadgeText:(NSString *)badgeText {
    _badgeText = badgeText;
    [self updateBadge: badgeText];
    self.badgeLayer.string = badgeText;
}

- (void) updateBadge: (NSString*) text {
    if (text) {
        self.badgeLayer.opacity = 1;
        self.badgeLayer.fontSize = [self fontSize];

        CTTextAlignment alignment = kCTCenterTextAlignment;
        CTParagraphStyleSetting settings[] = {kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment};
        CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(settings[0]));


        NSDictionary * attributes = @{(id)kCTFontAttributeName: (__bridge id)CTFontCreateWithName((CFStringRef)@"Helvetica", self.badgeLayer.fontSize, NULL),
                                      (id)kCTParagraphStyleAttributeName: (__bridge id)paragraphStyle};

        NSAttributedString * attributedText = [[NSAttributedString alloc] initWithString: text attributes: attributes];
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedText);
        CFRelease(paragraphStyle);

        CGRect bounds = CGRectZero;
        bounds.size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(0, 0), NULL);
        CFRelease(framesetter);

        bounds.size.width = MAX(bounds.size.width + 2 * [self badgePadding], bounds.size.height);

        self.badgeLayer.bounds = bounds;
        self.badgeLayer.cornerRadius = bounds.size.height / 2;
    } else {
        self.badgeLayer.opacity = 0;
    }
}

- (CAShapeLayer*) maskLayer {
    CAShapeLayer * mask = [CAShapeLayer layer];
    mask.path = [UIBezierPath bezierPathWithOvalInRect: self.avatarLayer.bounds].CGPath;
    return mask;
}

- (void) setImage:(UIImage *)image {
    _image = image;
    self.avatarLayer.contents = (id)image.CGImage;
    self.defaultAvatarLayer.opacity = image ? 0 : 1;
    [self setNeedsDisplay];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGFloat size = MIN(self.bounds.size.width, self.bounds.size.height) - self.padding;
    CGRect bounds = CGRectMake(0, 0, size, size);
    CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    self.avatarLayer.bounds = bounds;
    self.avatarLayer.mask = [self maskLayer];
    self.avatarLayer.position = center;

    self.defaultAvatarLayer.bounds = bounds;
    self.defaultAvatarLayer.mask = [self maskLayer];
    self.defaultAvatarLayer.position = center;

    size = size - [self blockedSignPadding];
    self.blockedSignLayer.bounds = CGRectMake(0, 0, size, size);
    self.blockedSignLayer.position = center;

    // XXX there has to be a better way to do this ...
    self.defaultAvatarLayer.path = [self.defaultIcon pathScaledToSize: self.defaultAvatarLayer.bounds.size].CGPath;
    self.blockedSignLayer.path = [self.blockedSign pathScaledToSize: self.blockedSignLayer.bounds.size].CGPath;

    self.badgeLayer.position = CGPointMake(CGRectGetMaxX(self.avatarLayer.frame), self.padding / 2);
    [self updateBadge: self.badgeText];

}

- (CGFloat) blockedSignPadding {
    return ceilf(kHXOGridSpacing * (kBlockedSignPaddingFactor * self.avatarLayer.bounds.size.width + kBlockedSignPaddingOffset));
}

- (CGFloat) fontSize {
    return  kBadgeFontSizeFactor * self.avatarLayer.bounds.size.width + kBadgeFontSizeOffset;
}

- (CGFloat) badgePadding {
    return kBadgePaddingFactor * self.avatarLayer.bounds.size.width + kBadgePaddingOffset;
}

- (void) setPadding:(CGFloat)padding {
    _padding = padding;
    [self setNeedsLayout];
}

- (void) setDefaultIcon:(VectorArt *)defaultIcon {
    _defaultIcon = defaultIcon;
    _defaultAvatarLayer.fillColor = defaultIcon.fillColor.CGColor;
    _defaultAvatarLayer.strokeColor = defaultIcon.strokeColor.CGColor;
    //[self setNeedsLayout];
}

- (void) setBlockedSign:(VectorArt *)blockedSign {
    _blockedSign = blockedSign;
    self.blockedSignLayer.fillColor = blockedSign.fillColor.CGColor;
    self.blockedSignLayer.strokeColor = blockedSign.strokeColor.CGColor;
}

- (void) setIsBlocked:(BOOL)isBlocked {
    _isBlocked = isBlocked;
    _blockedSignLayer.opacity = isBlocked ? 1 : 0;
}

@end