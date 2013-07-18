//
//  BubbleViewToo.m
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleViewToo.h"

#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#import "InsetImageView.h"
#import "HXOLinkyLabel.h"

static const CGFloat kHXOBubblePadding = 8;
static const CGFloat kHXOBubbleMinimumHeight = 48;

@implementation BubbleViewToo

- (id) init {
    self = [super init];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentMode = UIViewContentModeRedraw;
    self.backgroundColor = [UIColor clearColor];

    _avatar = [[InsetImageView alloc] initWithFrame: CGRectMake(kHXOBubblePadding, kHXOBubblePadding, kHXOBubbleMinimumHeight, kHXOBubbleMinimumHeight)];
    [self addSubview: _avatar];

    self.colorScheme = HXOBubbleColorSchemeWhite;
    self.messageDirection = HXOMessageDirectionOutgoing;

    self.layer.shouldRasterize = YES;
    self.layer.shadowOffset = CGSizeMake(0.1, 2.1);
    [self configureDropShadow];

}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    _colorScheme = colorScheme;
    [self configureDropShadow];
    [self setNeedsLayout];
}

- (void) setMessageDirection:(HXOMessageDirection)messageDirection {
    _messageDirection = messageDirection;
    CGRect frame = _avatar.frame;
    if (messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x = kHXOBubblePadding;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    } else {
        frame.origin.x = self.bounds.size.width - frame.size.width - kHXOBubblePadding;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
    _avatar.frame = frame;
    [self configureDropShadow];
    [self setNeedsLayout];
}

- (CGFloat) calculateHeightForWidth: (CGFloat) width {
    return kHXOBubbleMinimumHeight + 2 * kHXOBubblePadding;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [self createShadowPath].CGPath;
    [self setNeedsDisplay];
}

- (UIBezierPath*) createShadowPath {
     return [self createBubblePathInRect: [self bubbleFrame]];
}

- (void) configureDropShadow {
    BOOL hasShadow = self.colorScheme != HXOBubbleColorSchemeEtched;
    self.layer.shadowColor = hasShadow ? [UIColor blackColor].CGColor : NULL;
    self.layer.shadowOpacity = hasShadow ? 0.15 : 0;
    self.layer.shadowRadius = hasShadow ? 2 : 0;
}

- (void)drawRect:(CGRect)rect {
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    [self drawPlainBubble: context withFillImage: nil innerGlowAlpha: 0.3];
}

- (void)drawPlainBubble:(CGContextRef) context withFillImage: (UIImage*) fillImage innerGlowAlpha: (CGFloat) glowAlpha {

    BOOL isEtched = self.colorScheme == HXOBubbleColorSchemeEtched;

    //// Color Declarations
    UIColor* bubbleFillColor = [self fillColor];
    UIColor* bubbleStrokeColor = [self strokeColor];
    CGFloat innerShadowAlpha = isEtched ? 0.15 : 0.07;
    UIColor* bubbleInnerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: innerShadowAlpha];

    //// Shadow Declarations
    UIColor* bubbleInnerShadow = bubbleInnerShadowColor;
    CGSize bubbleInnerShadowOffset = isEtched ? CGSizeMake(0.1, 2.1) : CGSizeMake(0.1, -2.1);
    CGFloat bubbleInnerShadowBlurRadius = isEtched ? 5 : 3;

    CGRect bubbleRect = [self bubbleFrame];

    //// Bubble Drawing
    UIBezierPath* bubblePath = [self createBubblePathInRect: bubbleRect];
    
    CGContextSaveGState(context);
    if (fillImage != nil) {
        CGContextSaveGState(context);
        [bubblePath addClip];
        [fillImage drawInRect: bubbleRect];
        CGContextRestoreGState(context);
    } else {
        [bubbleFillColor setFill];
        [bubblePath fill];
    }

    ////// Bubble Inner Shadow
    CGRect bubbleBorderRect = CGRectInset([bubblePath bounds], -bubbleInnerShadowBlurRadius, -bubbleInnerShadowBlurRadius);
    bubbleBorderRect = CGRectOffset(bubbleBorderRect, -bubbleInnerShadowOffset.width, -bubbleInnerShadowOffset.height);
    bubbleBorderRect = CGRectInset(CGRectUnion(bubbleBorderRect, [bubblePath bounds]), -1, -1);

    UIBezierPath* bubbleNegativePath = [UIBezierPath bezierPathWithRect: bubbleBorderRect];
    [bubbleNegativePath appendPath: bubblePath];
    bubbleNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = bubbleInnerShadowOffset.width + round(bubbleBorderRect.size.width);
        CGFloat yOffset = bubbleInnerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    bubbleInnerShadowBlurRadius,
                                    bubbleInnerShadow.CGColor);

        [bubblePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(bubbleBorderRect.size.width), 0);
        [bubbleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [bubbleNegativePath fill];
    }
    CGContextRestoreGState(context);


    CGContextRestoreGState(context);

    if (self.colorScheme != HXOBubbleColorSchemeEtched) {
        [self drawInnerGlow: context path: bubblePath alpha: glowAlpha];
    }

    [bubbleStrokeColor setStroke];
    bubblePath.lineWidth = 1;
    [bubblePath stroke];
}

- (void) drawInnerGlow: (CGContextRef) context path: (UIBezierPath*) path alpha: (CGFloat) alpha {
    UIColor * innerGlowColor = [UIColor colorWithWhite: 1.0 alpha: alpha];

    CGContextSaveGState(context);

    path.lineWidth = 3;
    path.lineJoinStyle = kCGLineJoinRound;

    [path addClip];

    [innerGlowColor setStroke];
    [path stroke];

    CGContextRestoreGState(context);
}

- (CGRect) bubbleFrame {
    CGRect frame = CGRectInset(self.bounds, kHXOBubblePadding, kHXOBubblePadding);
    CGFloat dx = kHXOBubbleMinimumHeight + kHXOBubblePadding;
    frame.size.width -= dx;
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x += dx;
    }
    return frame;
}

- (UIBezierPath*) createBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath;
    if (self.messageDirection == HXOMessageDirectionOutgoing) {
        bubblePath = [self rightPointingBubblePathInRect: frame];
    } else {
        bubblePath = [self leftPointingBubblePathInRect: frame];
    }
    return bubblePath;
}

- (UIBezierPath*) rightPointingBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 27.07)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 1.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMaxY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 0.4)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 2)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMinY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMinY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 0.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 18.43)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3.5, CGRectGetMinY(frame) + 20.01) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 19.53) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 5.04, CGRectGetMinY(frame) + 20)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 18.43) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 2.04, CGRectGetMinY(frame) + 20.01) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 19.53)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 27.07) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 22.71) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 2.99, CGRectGetMinY(frame) + 26.16)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIBezierPath*) leftPointingBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 27.07)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 1.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMaxY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 0.4)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 2)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMinY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMinY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 0.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 18.43)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 3.5, CGRectGetMinY(frame) + 20.01) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 19.53) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 5.04, CGRectGetMinY(frame) + 20)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 18.43) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 2.04, CGRectGetMinY(frame) + 20.01) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 19.53)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 27.07) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 22.71) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 2.99, CGRectGetMinY(frame) + 26.16)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIColor*) fillColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor whiteColor];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 0.855 green: 0.925 blue: 0.996 alpha: 1];
        case HXOBubbleColorSchemeEtched:
            return [UIColor colorWithWhite: 0.95 alpha: 1.0];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 0.996 green: 0.796 blue: 0.804 alpha: 1];
    }
}

- (UIColor*) strokeColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor colorWithWhite: 0.75 alpha: 1.0];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 0.49 green: 0.663 blue: 0.792 alpha: 1];
        case HXOBubbleColorSchemeEtched:
            return [UIColor whiteColor];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 0.792 green: 0.314 blue: 0.329 alpha: 1];
    }
}


@end

@implementation TextMessageCell

- (void) commonInit {
    [super commonInit];

    _label = [[HXOLinkyLabel alloc] init];
    _label.numberOfLines = 0;
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _label.backgroundColor = [UIColor clearColor /* colorWithWhite: 0.9 alpha: 1.0*/];
    _label.font = [UIFont systemFontOfSize: 13.0];
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    _label.shadowColor = [UIColor colorWithWhite: 1.0 alpha: 0.8];
    _label.shadowOffset = CGSizeMake(0, 1);
    [self addSubview: _label];
}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    [super setColorScheme: colorScheme];
    _label.textColor = [self textColorForColorScheme: colorScheme];
    _label.defaultTokenStyle = [self linkStyleForColorScheme: colorScheme];
}

- (CGFloat) calculateHeightForWidth: (CGFloat) width {
    CGRect frame = CGRectMake(0, 0, [self textWidthForWidth: width], 10000
    );
    _label.frame = frame;
    if (_label.currentNumberOfLines <= 2) {
        return kHXOBubbleMinimumHeight + 2 * kHXOBubblePadding;
    } else {
        CGSize textSize = [_label sizeThatFits: CGSizeMake([self textWidthForWidth: width], 0)];
        return textSize.height + 4 * kHXOBubblePadding;
    }
}

- (void) layoutSubviews {
    [super layoutSubviews];
    _label.frame = [self textFrame];
    [_label sizeToFit];
    CGRect textFrame = _label.frame;
    textFrame.origin.y = 0.5 * (self.bounds.size.height - textFrame.size.height);
    NSUInteger numberOfLines = _label.currentNumberOfLines;
    if (numberOfLines == 1) {
        textFrame.origin.y -= 2;
    } else {
        textFrame.origin.y -= 1;
    }
    _label.frame = textFrame;
}

- (CGRect) textFrame {
    CGRect frame = CGRectInset(self.bounds, 0, 2 * kHXOBubblePadding);
    frame.size.width = [self textWidthForWidth: self.bounds.size.width];
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x += kHXOBubbleMinimumHeight +  4 * kHXOBubblePadding;
    } else {
        frame.origin.x += 2 * kHXOBubblePadding;
    }
    return frame;
}

- (CGFloat) textWidthForWidth: (CGFloat) width {
    return width - (kHXOBubbleMinimumHeight + 6 * kHXOBubblePadding);
}

- (UIColor*) textColorForColorScheme: (HXOBubbleColorScheme) colorScheme {
    switch (colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor colorWithRed: 51.0/255 green: 51.0/255 blue: 51.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 32.0/255 green: 92.0/255 blue: 153.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeEtched:
            return [UIColor colorWithRed: 153.0/255 green: 153.0/255 blue: 153.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 153.0/255 green: 31.0/255 blue: 31.0/255 alpha: 1.0];
    }
}

- (NSDictionary*) linkStyleForColorScheme: (HXOBubbleColorScheme) colorScheme {
    UIColor * color;
    switch (colorScheme) {
        case HXOBubbleColorSchemeWhite:
            color = [UIColor colorWithRed: 0.0/255 green: 85.0/255 blue: 255.0/255 alpha: 1.0];
            break;
        case HXOBubbleColorSchemeBlue:
            color = [UIColor colorWithRed: 0.0/255 green: 0.0/255 blue: 229.0/255 alpha: 1.0];
            break;
        case HXOBubbleColorSchemeEtched:
            color = [UIColor colorWithRed: 61.0/255 green: 77.0/255 blue: 153.0/255 alpha: 1.0];
            break;
        case HXOBubbleColorSchemeRed:
            color = [UIColor colorWithRed: 18.0/255 green: 18.0/255 blue: 179.0/255 alpha: 1.0];
            break;
    }
    return @{(id)kCTForegroundColorAttributeName: (id)color.CGColor};
}

@end

@implementation AttachmentMessageCell

- (UIColor*) fillColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithPatternImage: [UIImage imageNamed:@"attachment_pattern_red"]];
        default:
            return [UIColor colorWithPatternImage: [UIImage imageNamed:@"attachment_pattern"]];
    }
}

- (UIColor*) strokeColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 107.0/255 green: 21.0/255 blue: 24.0/255 alpha: 1.0];
        default:
            return [UIColor colorWithRed: 0.19 green: 0.195 blue: 0.2 alpha: 1];
    }
}

- (UIBezierPath*) createShadowPath {
    CGRect frame = [self bubbleFrame];
    UIBezierPath* bubblePath;
    if (self.messageDirection == HXOMessageDirectionOutgoing) {
        bubblePath = [super rightPointingBubblePathInRect: frame];
    } else {
        bubblePath = [super leftPointingBubblePathInRect: frame];
    }
    return bubblePath;
}

- (void)drawRect:(CGRect)rect {
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (self.attachmentStyle == HXOAttachmentStyleThumbnail) {
        [self drawPlainBubble: context withFillImage: nil innerGlowAlpha: 0.2];
        [self drawThumbnailInContext: context];
        [self drawAttachmentTextInContext: context];
    } else {
        [self drawPlainBubble: context withFillImage: self.previewImage innerGlowAlpha: 0.3];
    }
}

- (void) drawThumbnailInContext: (CGContextRef) context {

    UIColor* thumbnailFrameColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    CGRect frame = [self bubbleFrame];

    UIBezierPath* thumbnailFramePath = self.messageDirection == HXOMessageDirectionIncoming ? [self rightAlignedThumbnailFrameInRect: frame] : [self leftAlignedThumbnailFrameInRect: frame];

    
    CGContextSaveGState(context);
    [thumbnailFramePath addClip];

    CGRect thumbnailFrameBounds = CGPathGetPathBoundingBox(thumbnailFramePath.CGPath);

    if (self.previewImage == nil) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        UIColor* thumbnailFrameGradientDark = [UIColor colorWithRed: 0.102 green: 0.102 blue: 0.102 alpha: 1];
        UIColor* thumbnailFrameGradientLight = [UIColor colorWithRed: 0.149 green: 0.149 blue: 0.149 alpha: 1];

        NSArray* thumbnailFrameGradientColors = [NSArray arrayWithObjects:
                                                 (id)thumbnailFrameGradientDark.CGColor,
                                                 (id)thumbnailFrameGradientLight.CGColor, nil];
        CGFloat thumbnailFrameGradientLocations[] = {0, 1};
        CGGradientRef thumbnailFrameGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)thumbnailFrameGradientColors, thumbnailFrameGradientLocations);


        CGContextDrawLinearGradient(context, thumbnailFrameGradient,
                                    CGPointMake(CGRectGetMidX(thumbnailFrameBounds), CGRectGetMinY(thumbnailFrameBounds)),
                                    CGPointMake(CGRectGetMidX(thumbnailFrameBounds), CGRectGetMaxY(thumbnailFrameBounds)),
                                    0);
        CGGradientRelease(thumbnailFrameGradient);
        CGColorSpaceRelease(colorSpace);

        UIImage * icon = self.largeAttachmentTypeIcon;
        CGPoint iconOrigin = CGPointMake(thumbnailFrameBounds.origin.x + 0.5 * thumbnailFrameBounds.size.width - 0.5 * icon.size.width,
                                         thumbnailFrameBounds.origin.y + 0.5 * thumbnailFrameBounds.size.height - 0.5 * icon.size.height);
        [icon drawAtPoint: iconOrigin];

    } else {
        [self.previewImage drawInRect: [self thumbnailFrame: thumbnailFrameBounds]];
    }
    CGContextRestoreGState(context);
    [thumbnailFrameColor setStroke];
    thumbnailFramePath.lineWidth = 1;
    [thumbnailFramePath stroke];
}

- (void) drawAttachmentTextInContext: (CGContextRef) context {

    CGRect frame = [self bubbleFrame];
    
    //// Text Drawing
    CGRect textRect;
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        textRect = CGRectMake(CGRectGetMinX(frame) + 16, CGRectGetMinY(frame) + 15, CGRectGetWidth(frame) - 56, 16);
    } else {
        textRect = CGRectMake(CGRectGetMinX(frame) + 56, CGRectGetMinY(frame) + 15, CGRectGetWidth(frame) - 16, 16);

    }
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 0, [UIColor blackColor].CGColor);
    [[UIColor whiteColor] setFill];
    [self.attachmentText drawInRect: textRect withFont: [UIFont italicSystemFontOfSize: 13.0] lineBreakMode: NSLineBreakByTruncatingTail alignment: NSTextAlignmentLeft];
    CGContextRestoreGState(context);

}

- (UIBezierPath*) leftAlignedThumbnailFrameInRect: (CGRect) frame {
    UIBezierPath* thumbnailFramePath = [UIBezierPath bezierPath];
    [thumbnailFramePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMaxY(frame) - 1.5)];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 46, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 47.1, CGRectGetMaxY(frame))];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMaxY(frame))];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 0.4)];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 2)];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMinY(frame))];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 46, CGRectGetMinY(frame))];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 47.1, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMinY(frame) + 0.9)];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMaxY(frame) - 1.5)];
    [thumbnailFramePath closePath];

    return thumbnailFramePath;
}

- (UIBezierPath*) rightAlignedThumbnailFrameInRect: (CGRect) frame {
    UIBezierPath* thumbnailFramePath = [UIBezierPath bezierPath];
    [thumbnailFramePath moveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 1.5)];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMaxY(frame))];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 46, CGRectGetMaxY(frame))];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 47.1, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMaxY(frame) - 0.4)];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMinY(frame) + 2)];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 46, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 47.1, CGRectGetMinY(frame))];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMinY(frame))];
    [thumbnailFramePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 0.9)];
    [thumbnailFramePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 1.5)];
    [thumbnailFramePath closePath];

    return thumbnailFramePath;
}

- (CGRect) thumbnailFrame: (CGRect) frame {
    CGFloat scale;
    if (self.previewImage.size.width > self.previewImage.size.height) {
        scale = kHXOBubbleMinimumHeight / self.previewImage.size.height;
    } else {
        scale = kHXOBubbleMinimumHeight / self.previewImage.size.width;
    }
    CGFloat dx = 0.5 * (scale * self.previewImage.size.width - frame.size.width);
    CGFloat dy = 0.5 * (scale * self.previewImage.size.height - frame.size.height);
    return CGRectInset(frame, -dx, -dy);
}

- (CGFloat) calculateHeightForWidth: (CGFloat) width {
    CGFloat imageWidth = [self imageWidthForWidth: width];
    CGFloat bubbleHeight;
    switch (self.attachmentStyle) {
        case HXOAttachmentStyleThumbnail:
            bubbleHeight = 48;
            break;
        case HXOAttachmentStyleOriginalAspect:
        {
            CGFloat aspect = self.previewImage.size.height / self.previewImage.size.width;
            bubbleHeight = imageWidth * aspect;
            break;
        }
        case HXOAttachmentStyleCropped16To9:
            bubbleHeight = imageWidth * (16.0/9);
            break;
    }
    return bubbleHeight + 2 * kHXOBubblePadding;
}

- (CGFloat) imageWidthForWidth: (CGFloat) width {
    return width - (kHXOBubbleMinimumHeight + 3 * kHXOBubblePadding);

}

- (UIBezierPath*) rightPointingBubblePathInRect: (CGRect) frame {
    if (self.attachmentStyle != HXOAttachmentStyleThumbnail) {
        return [super rightPointingBubblePathInRect: frame];
    }

    UIBezierPath* thumbnailedBubblePathPath = [UIBezierPath bezierPath];
    [thumbnailedBubblePathPath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 2)];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 18.43)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3.5, CGRectGetMinY(frame) + 20.01) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 19.53) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 5.04, CGRectGetMinY(frame) + 20)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 18.43) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 2.04, CGRectGetMinY(frame) + 20.01) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 19.53)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 27.07) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 22.71) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 2.99, CGRectGetMinY(frame) + 26.16)];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 1.5)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMaxY(frame))];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 46, CGRectGetMaxY(frame))];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 47.1, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMaxY(frame) - 0.4)];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMinY(frame) + 2)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 46, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 48, CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 47.1, CGRectGetMinY(frame))];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMinY(frame))];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 0.9)];
    [thumbnailedBubblePathPath closePath];

    return thumbnailedBubblePathPath;
}

- (UIBezierPath*) leftPointingBubblePathInRect: (CGRect) frame {
    if (self.attachmentStyle != HXOAttachmentStyleThumbnail) {
        return [super leftPointingBubblePathInRect: frame];
    }

    UIBezierPath* thumbnailedBubblePathPath = [UIBezierPath bezierPath];
    [thumbnailedBubblePathPath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 2)];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 18.43)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 3.5, CGRectGetMinY(frame) + 20.01) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 19.53) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 5.04, CGRectGetMinY(frame) + 20)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 18.43) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 2.04, CGRectGetMinY(frame) + 20.01) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 19.53)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 27.07) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 22.71) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 2.99, CGRectGetMinY(frame) + 26.16)];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 1.5)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMaxY(frame))];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 46, CGRectGetMaxY(frame))];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 47.1, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMaxY(frame) - 0.4)];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMinY(frame) + 2)];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 46, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 48, CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 47.1, CGRectGetMinY(frame))];
    [thumbnailedBubblePathPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMinY(frame))];
    [thumbnailedBubblePathPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 0.9)];
    [thumbnailedBubblePathPath closePath];

    return thumbnailedBubblePathPath;
}

@end
