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
#import "ghost_busters_sign.h"
#import "HXOUI.h"

static const CGFloat kBlockedSignPaddingOffset = -0.541667;
static const CGFloat kBlockedSignPaddingFactor = 0.0260417;

static const CGFloat kBadgeFontSizeOffset = 49.0 / 6.0;
static const CGFloat kBadgeFontSizeFactor = 7.0 / 48;

static const CGFloat kBadgePaddingOffset = 7.0 / 4;
static const CGFloat kBadgePaddingFactor =  1.0 / 32;

static const CGFloat kBadgeBorderWidthOffset = 19.0 / 12;
static const CGFloat kBadgeBorderWidthFactor =  1.0 / 96;

static const CGFloat kBadgeXAnchorOffset = 0.475;
static const CGFloat kBadgeXAnchorFactor = 0.003125;

static const CGFloat kLedSizeOffset = 1;
static const CGFloat kLedSizeFactor = 0.013;

static const CGFloat kLedBorderWidthOffset = 7.0 / 12;
static const CGFloat kLedBorderWidthFactor = 1.0 / 96;


@interface AvatarView ()

@property (nonatomic, strong) CALayer      * avatarLayer;
@property (nonatomic, strong) CAShapeLayer * defaultAvatarLayer;
@property (nonatomic, strong) CAShapeLayer * blockedSignLayer;
@property (nonatomic, strong) CATextLayer  * badgeTextLayer;
@property (nonatomic, strong) CAShapeLayer * badgeBackgroundLayer;
@property (nonatomic, strong) CAShapeLayer * ledLayer;
@property (nonatomic, strong) CAShapeLayer * circleMask;

@end


@implementation AvatarView

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame: frame];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    //self.layer.backgroundColor = [UIColor lightGrayColor].CGColor;

    CGFloat size = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    self.layer.contentsGravity = kCAGravityResizeAspect;

    self.avatarLayer = [CALayer layer];
    self.avatarLayer.bounds = CGRectMake(0, 0, size, size);
    self.avatarLayer.position = self.center;
    self.avatarLayer.contentsGravity = kCAGravityResizeAspectFill;
    self.avatarLayer.backgroundColor = [HXOUI theme].defaultAvatarBackgroundColor.CGColor;
    [self.layer addSublayer: self.avatarLayer];

    CGPoint avatarCenter = CGPointMake(self.avatarLayer.bounds.size.width / 2, self.avatarLayer.bounds.size.height / 2);
    self.defaultAvatarLayer = [CAShapeLayer layer];
    self.defaultAvatarLayer.bounds = self.avatarLayer.bounds;
    self.defaultAvatarLayer.position = avatarCenter;
    self.defaultAvatarLayer.contentsGravity = kCAGravityResizeAspect;
    [self.avatarLayer addSublayer: self.defaultAvatarLayer];

    self.blockedSignLayer = [CAShapeLayer layer];
    CGFloat blockSignSize = size - [self blockedSignPadding];
    self.blockedSignLayer.bounds = CGRectMake(0, 0, blockSignSize, blockSignSize);
    self.blockedSignLayer.position = avatarCenter;
    self.blockedSignLayer.contentsGravity = kCAGravityResizeAspect;
    self.blockedSignLayer.opacity = 0;
    VectorArt * blockedSign = [[ghost_busters_sign alloc] init];
    self.blockedSignLayer.fillColor = blockedSign.fillColor.CGColor;
    self.blockedSignLayer.strokeColor = blockedSign.strokeColor.CGColor;
    _blockedSignLayer.path = [blockedSign pathScaledToSize: self.blockedSignLayer.bounds.size].CGPath;
    [self.avatarLayer addSublayer: self.blockedSignLayer];
    //self.blockedSignLayer.backgroundColor = [UIColor orangeColor].CGColor;

    self.badgeTextLayer = [CATextLayer layer];
    self.badgeTextLayer.bounds = CGRectMake(0,0,20,20);
    self.badgeTextLayer.contentsScale = [UIScreen mainScreen].scale;
    self.badgeTextLayer.alignmentMode = kCAAlignmentCenter;
    self.badgeTextLayer.anchorPoint = CGPointMake([self badgeXAnchor], 0);
    //self.badgeTextLayer.backgroundColor = [HXOUI theme].avatarBadgeColor.CGColor;
    self.badgeTextLayer.position = CGPointMake(CGRectGetMaxX(self.avatarLayer.bounds), 0);
    self.badgeTextLayer.opacity = 0;
    self.badgeBackgroundLayer = [CAShapeLayer layer];
    self.badgeBackgroundLayer.anchorPoint = self.badgeTextLayer.anchorPoint;
    self.badgeBackgroundLayer.bounds = self.badgeTextLayer.bounds;
    self.badgeBackgroundLayer.position = self.badgeTextLayer.position;
    self.badgeBackgroundLayer.path = [UIBezierPath bezierPathWithRoundedRect: self.badgeBackgroundLayer.bounds cornerRadius: 0.5 * self.badgeBackgroundLayer.bounds.size.height].CGPath;
    self.badgeBackgroundLayer.fillColor = [HXOUI theme].avatarBadgeColor.CGColor;
    self.badgeBackgroundLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.badgeBackgroundLayer.lineWidth = [self badgeBorderWidth];
    [self.layer addSublayer: self.badgeBackgroundLayer];
    [self.layer addSublayer: self.badgeTextLayer];
    self.badgeBackgroundLayer.frame = self.badgeTextLayer.frame;

    CGFloat t = 0.5 * self.avatarLayer.frame.size.height;
    CGFloat ledX = t - (t / sqrt(2));
    self.ledLayer = [CAShapeLayer layer];
    self.ledLayer.bounds = CGRectMake(0, 0, [self ledSize], [self ledSize]);
    self.ledLayer.path = [UIBezierPath bezierPathWithOvalInRect: CGRectInset(self.ledLayer.bounds, 0.5, 0.5)].CGPath;
    self.ledLayer.fillColor = [HXOUI theme].avatarOnlineLedColor.CGColor;
    self.ledLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.ledLayer.lineWidth = [self ledBorderWidth];
    self.ledLayer.opacity = 0;
    self.ledLayer.position = CGPointMake(ledX, self.avatarLayer.frame.size.height - ledX);
    [self.layer addSublayer: self.ledLayer];

    self.circleMask = [CAShapeLayer layer];
    self.circleMask.bounds = self.avatarLayer.bounds;
    self.circleMask.position = avatarCenter;
    self.circleMask.path = [UIBezierPath bezierPathWithOvalInRect: self.circleMask.bounds].CGPath;

    self.avatarLayer.mask = self.circleMask;

    self.badgeText = nil;

    [self setNeedsLayout];
}

- (CGSize) intrinsicContentSize {
    return self.bounds.size;
}

- (void) layoutSublayersOfLayer:(CALayer *)layer {
    [super layoutSublayersOfLayer: layer];
    if ([layer isEqual: self.layer]) {

        self.avatarLayer.position = CGPointMake(0.5 * layer.bounds.size.width, 0.5 * layer.bounds.size.height);
        CGFloat size = MIN(layer.bounds.size.width, layer.bounds.size.height);
        CGFloat scale = size / self.avatarLayer.frame.size.width;
        self.avatarLayer.transform = CATransform3DScale(self.avatarLayer.transform, scale, scale, scale);
        //self.avatarLayer.bounds = CGRectMake(0, 0, size, size);

        self.badgeTextLayer.position = CGPointMake(CGRectGetMaxX(self.avatarLayer.frame), CGRectGetMinY(self.avatarLayer.frame));
        self.badgeBackgroundLayer.position = self.badgeTextLayer.position;

        CGFloat t = 0.5 * self.avatarLayer.frame.size.height;
        CGFloat ledX = t - (t / sqrt(2));

        self.ledLayer.position = CGPointMake(roundf(ledX) + .5, roundf(self.avatarLayer.frame.size.height - ledX) + .5);
        //self.ledLayer.bounds = CGRectMake(0, 0, [self ledSize], [self ledSize]);

        [self updateBadge: self.badgeText];

    }
}

- (void) setImage:(UIImage *)image {
    _image = image;
    self.avatarLayer.contents = (id)image.CGImage;
    self.defaultAvatarLayer.opacity = image ? 0 : 1;
}


- (void) setDefaultIcon:(VectorArt *)defaultIcon {
    _defaultIcon = defaultIcon;
    _defaultAvatarLayer.fillColor = defaultIcon.fillColor.CGColor;
    _defaultAvatarLayer.strokeColor = defaultIcon.strokeColor.CGColor;
    _defaultAvatarLayer.path = [defaultIcon pathScaledToSize: _defaultAvatarLayer.bounds.size].CGPath;
}

- (void) setBadgeText:(NSString *)badgeText {
    _badgeText = badgeText;
    [self updateBadge: badgeText];
    self.badgeTextLayer.string = badgeText;
    [self setNeedsLayout];
}

- (void) setIsBlocked:(BOOL)isBlockedFlag {
    _isBlocked = isBlockedFlag;
    self.blockedSignLayer.opacity = isBlockedFlag ? 1 : 0;
}

- (void) setIsPresent:(BOOL)isPresentFlag {
    _isPresent = isPresentFlag;
    self.ledLayer.opacity = isPresentFlag ? 1 : 0;
}

- (CGFloat) blockedSignPadding {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return ceilf(kHXOGridSpacing * (kBlockedSignPaddingFactor * t + kBlockedSignPaddingOffset));
}

- (CGFloat) badgeFontSize {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return  kBadgeFontSizeFactor * t + kBadgeFontSizeOffset;
}

- (CGFloat) badgeXAnchor {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return kBadgeXAnchorFactor * t + kBadgeXAnchorOffset;
}
- (CGFloat) badgePadding {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return kBadgePaddingFactor * t + kBadgePaddingOffset;
}

- (CGFloat) badgeBorderWidth {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return kBadgeBorderWidthFactor * t + kBadgeBorderWidthOffset;
}

- (CGFloat) ledSize {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return roundf(kHXOGridSpacing * (kLedSizeFactor * t + kLedSizeOffset));
}

- (CGFloat) ledBorderWidth {
    CGFloat t = MIN(self.layer.bounds.size.width, self.layer.bounds.size.height);
    return kLedBorderWidthFactor * t + kLedBorderWidthOffset;
}

- (void) updateBadge: (NSString*) text {
    if (text) {
        self.badgeTextLayer.opacity = 1;
        self.badgeBackgroundLayer.opacity = 1;
        self.badgeTextLayer.fontSize = [self badgeFontSize];

        CTTextAlignment alignment = kCTCenterTextAlignment;
        CTParagraphStyleSetting settings[] = {kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment};
        CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(settings, sizeof(settings) / sizeof(settings[0]));


        NSDictionary * attributes = @{(id)kCTFontAttributeName: CFBridgingRelease(CTFontCreateWithName((CFStringRef)@"Helvetica", self.badgeTextLayer.fontSize, NULL)),
                                      (id)kCTParagraphStyleAttributeName: (__bridge id)paragraphStyle};

        NSAttributedString * attributedText = [[NSAttributedString alloc] initWithString: text attributes: attributes];
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedText);
        CFRelease(paragraphStyle);

        CGRect bounds = CGRectZero;
        bounds.size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(0, 0), NULL);
        CFRelease(framesetter);

        bounds.size.width = MAX(bounds.size.width + 2 * [self badgePadding], bounds.size.height);
        self.badgeTextLayer.bounds = bounds;
        self.badgeBackgroundLayer.frame = self.badgeTextLayer.frame;
        self.badgeBackgroundLayer.path = [UIBezierPath bezierPathWithRoundedRect: self.badgeBackgroundLayer.bounds cornerRadius: 0.5 * self.badgeBackgroundLayer.bounds.size.height].CGPath;
    } else {
        self.badgeTextLayer.opacity = 0;
        self.badgeBackgroundLayer.opacity = 0;
    }
}

@end