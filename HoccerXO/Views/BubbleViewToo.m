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

#import "InsetImageView2.h"
#import "HXOLinkyLabel.h"
#import "HXOProgressView.h"
#import "HXOUserDefaults.h"

static const CGFloat kHXOBubblePadding = 8;
static const CGFloat kHXOBubbleMinimumHeight = 48;
static const CGFloat kHXOBubbleTypeIconSize = 16;
static const CGFloat kHXOBubbleTypeIconPadding = 3;
static const CGFloat kHXOBubbleProgressSizeSmall = 70;
static const CGFloat kHXOBubbleProgressSizeLarge = 150;
static const CGFloat kHXOBubblePlayButtonSize = 49;
static const CGFloat kHXOBubbleBottomTextBoxOversize = 4;

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

    _avatar = [[InsetImageView2 alloc] initWithFrame: CGRectMake(kHXOBubblePadding, kHXOBubblePadding, kHXOBubbleMinimumHeight, kHXOBubbleMinimumHeight)];
    [self addSubview: _avatar];
    [_avatar addTarget: self action: @selector(avatarPressed:) forControlEvents: UIControlEventTouchUpInside];

    self.colorScheme = HXOBubbleColorSchemeWhite;
    self.messageDirection = HXOMessageDirectionOutgoing;

    self.layer.shouldRasterize = YES;
    self.layer.shadowOffset = CGSizeMake(0.1, 2.1);
    [self configureDropShadow];

    _authorLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, kHXOBubbleMinimumHeight + kHXOBubblePadding, kHXOBubbleMinimumHeight + 2 * kHXOBubblePadding, 12)];
    _authorLabel.font = [UIFont systemFontOfSize: 10];
    _authorLabel.textColor = [UIColor colorWithWhite: 0.5 alpha: 1.0];
    _authorLabel.backgroundColor = [UIColor clearColor];
    _authorLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview: _authorLabel];
}


- (void) avatarPressed: (id) sender {
    if (self.delegate != nil) {
        [self.delegate messageCellDidPressAvatar: self];
    }
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
        _authorLabel.hidden = NO;
    } else {
        frame.origin.x = self.bounds.size.width - frame.size.width - kHXOBubblePadding;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        _authorLabel.hidden = YES;
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
    UIBezierPath * path = [self createBubblePathInRect: [self bubbleFrame]];
    CGFloat glowAlpha = self.colorScheme != HXOBubbleColorSchemeEtched ? 0.3 : 0.0;
    [self drawBubblePath: path inRect: [self bubbleFrame] fillColor: [self fillColor] strokeColor: [self strokeColor] withFillImage: nil innerGlowAlpha: glowAlpha isEtched: self.colorScheme == HXOBubbleColorSchemeEtched];
}

- (void)drawBubblePath: (UIBezierPath*) bubblePath inRect: (CGRect) bubbleRect fillColor: (UIColor*) fillColor strokeColor: (UIColor*) strokeColor withFillImage: (UIImage*) fillImage innerGlowAlpha: (CGFloat) glowAlpha isEtched: (BOOL) isEtched {

    CGContextRef context = UIGraphicsGetCurrentContext();

    //// Color Declarations
    UIColor* bubbleFillColor = fillColor;
    UIColor* bubbleStrokeColor = strokeColor;
    CGFloat innerShadowAlpha = isEtched ? 0.15 : 0.07;
    UIColor* bubbleInnerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: innerShadowAlpha];

    //// Shadow Declarations
    UIColor* bubbleInnerShadow = bubbleInnerShadowColor;
    CGSize bubbleInnerShadowOffset = isEtched ? CGSizeMake(0.1, 2.1) : CGSizeMake(0.1, -2.1);
    CGFloat bubbleInnerShadowBlurRadius = isEtched ? 5 : 3;

    //// Bubble Drawing    
    CGContextSaveGState(context);
    if (fillImage != nil) {
        CGContextSaveGState(context);
        [bubblePath addClip];
        [fillImage drawInRect: [self fillImageRectForImage: fillImage]];
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

    if (glowAlpha > 0) {
        [self drawInnerGlow: context path: bubblePath alpha: glowAlpha];
    }

    [bubbleStrokeColor setStroke];
    bubblePath.lineWidth = 1;
    [bubblePath stroke];
}

- (CGRect) fillImageRectForImage: (UIImage*) image {
    return [self bubbleFrame];
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


- (HXOLinkyLabel*) createMessageLabel {
    HXOLinkyLabel * label = [[HXOLinkyLabel alloc] init];
    label.numberOfLines = 0;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = [UIColor clearColor /* colorWithWhite: 0.9 alpha: 1.0*/];
    double fontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
//    label.font = [UIFont systemFontOfSize: 13.0];
    label.font = [UIFont systemFontOfSize: fontSize];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.shadowColor = [UIColor colorWithWhite: 1.0 alpha: 0.8];
    label.shadowOffset = CGSizeMake(0, 1);
    [self addSubview: label];
    return label;
}

- (void) configureTextColors: (HXOLinkyLabel*) label {
    label.textColor = [self textColorForColorScheme: self.colorScheme];
    label.defaultTokenStyle = [self linkStyleForColorScheme: self.colorScheme];
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

- (void) layoutLabel: (HXOLinkyLabel*) label {
    label.frame = [self textFrame];
    CGFloat maxTextHeight = label.frame.size.height;
    [label sizeToFit];
    CGRect textFrame = label.frame;
    textFrame.origin.y += 0.5 * (maxTextHeight - textFrame.size.height);
    NSUInteger numberOfLines = label.currentNumberOfLines;
    if (numberOfLines == 1) {
        textFrame.origin.y -= 2;
    } else {
        textFrame.origin.y -= 1;
    }
    label.frame = textFrame;

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


@end

@implementation TextMessageCell

- (void) commonInit {
    [super commonInit];

    _label = [self createMessageLabel];
}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    [super setColorScheme: colorScheme];
    [self configureTextColors: _label];
}

- (CGFloat) calculateHeightForWidth: (CGFloat) width {
    CGRect frame = CGRectMake(0, 0, [self textWidthForWidth: width], 10000);
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
    [self layoutLabel: _label];
}



@end

@implementation AttachmentMessageCell

- (void) commonInit {
    [super commonInit];

    _progressBar = [[HXOProgressView alloc] initWithFrame: CGRectMake(0, 0, kHXOBubbleProgressSizeLarge, 15)];
    _progressBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview: _progressBar];
    _progressBar.hidden = YES;

    _attachmentTitle = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 100, 16)];
    _attachmentTitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _attachmentTitle.font = [UIFont italicSystemFontOfSize: 13.0];
    _attachmentTitle.backgroundColor = [UIColor clearColor/* orangeColor*/];
    _attachmentTitle.textColor = [UIColor whiteColor];
    _attachmentTitle.shadowColor = [UIColor blackColor];
    _attachmentTitle.shadowOffset = CGSizeMake(0, -1);
    [self addSubview: _attachmentTitle];
}

- (void) setAttachmentTransferState:(HXOAttachmentTranserState)attachmentTransferState {
    _attachmentTransferState = attachmentTransferState;
    _progressBar.hidden = attachmentTransferState != HXOAttachmentTransferStateInProgress;
    _attachmentTitle.hidden = self.attachmentStyle != HXOAttachmentStyleThumbnail && self.attachmentTransferState != HXOAttachmentTranserStateDownloadPending;
    [self setNeedsLayout];
}

- (void) setAttachmentStyle:(HXOAttachmentStyle)attachmentStyle {
    _attachmentStyle = attachmentStyle;
    _attachmentTitle.hidden = self.attachmentStyle != HXOAttachmentStyleThumbnail && self.attachmentTransferState != HXOAttachmentTranserStateDownloadPending;
    [self setNeedsLayout];
}

- (CGRect) attachmentFrame {
    return [self bubbleFrame];
}

#pragma mark - Transfer Progress Indication Protocol

- (void) showTransferProgress:(float) theProgress {
    // NSLog(@"showTransferProgress %f", theProgress);

    self.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    self.progressBar.progress = theProgress;
}

- (void) transferStarted {
    self.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    self.progressBar.progress = 0;
}

- (void) transferFinished {
    self.attachmentTransferState = HXOAttachmentTransferStateDone;
}

// TODO: call when transfer is scheduled
- (void) transferScheduled {
    self.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    self.progressBar.progress = 0;
}

#pragma mark - Layout and Rendering

- (void) layoutSubviews {
    [super layoutSubviews];

    CGRect contentFrame = [self attachmentFrame];
    contentFrame.size.width -= kHXOBubblePadding;
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        contentFrame.origin.x += kHXOBubblePadding;
    }

    CGRect progressFrame = self.progressBar.frame;
    progressFrame.origin.y = contentFrame.origin.y + 0.5 * (contentFrame.size.height - progressFrame.size.height);

    if (self.attachmentStyle == HXOAttachmentStyleThumbnail) {
        CGRect labelFrame = self.attachmentTitle.frame;
        labelFrame.origin.y = contentFrame.origin.y + 0.5 * (contentFrame.size.height - labelFrame.size.height);
        labelFrame.origin.x = contentFrame.origin.x;
        labelFrame.size.width = contentFrame.size.width - (2 * kHXOBubblePadding + kHXOBubbleMinimumHeight);
        if (self.messageDirection == HXOMessageDirectionIncoming) {
            labelFrame.origin.x += kHXOBubblePadding;
        } else {
            labelFrame.origin.x += kHXOBubblePadding + kHXOBubbleMinimumHeight;
        }

        if (self.previewImage != nil) {
            labelFrame.origin.x += kHXOBubbleTypeIconSize + kHXOBubbleTypeIconPadding;
            labelFrame.size.width -= kHXOBubbleTypeIconSize + kHXOBubbleTypeIconPadding;
        }

        if (self.attachmentTransferState == HXOAttachmentTransferStateInProgress) {
            labelFrame.size.width -= kHXOBubbleProgressSizeSmall + kHXOBubblePadding;
            progressFrame.size.width = kHXOBubbleProgressSizeSmall;
            progressFrame.origin.x = labelFrame.origin.x + labelFrame.size.width + kHXOBubblePadding;
        }

        self.attachmentTitle.frame = labelFrame;
    } else {
        progressFrame.size.width = kHXOBubbleProgressSizeLarge;
        progressFrame.origin.x = contentFrame.origin.x + 0.5 * (contentFrame.size.width - progressFrame.size.width);
        if (self.runButtonStyle != HXOBubbleRunButtonNone) {
            CGRect runButtonFrame = [self runButtonFrame];
            progressFrame.origin.y = runButtonFrame.origin.y + runButtonFrame.size.height + kHXOBubblePadding;
        }
    }
    self.progressBar.frame = progressFrame;
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

    UIColor * fillColor;
    UIColor * strokeColor;
    if (self.colorScheme == HXOBubbleColorSchemeRed) {
        fillColor = [UIColor colorWithPatternImage: [UIImage imageNamed:@"attachment_pattern_red"]];
        strokeColor = [UIColor colorWithRed: 107.0/255 green: 21.0/255 blue: 24.0/255 alpha: 1.0];
    } else {
        fillColor = [UIColor colorWithPatternImage: [UIImage imageNamed:@"attachment_pattern"]];
        strokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    }
    if (self.attachmentStyle == HXOAttachmentStyleThumbnail) {
        UIBezierPath * path = [self thumbnailedBubblePathInRect: [self attachmentFrame]];
        [self drawBubblePath: path inRect: [self attachmentFrame] fillColor: fillColor strokeColor: strokeColor withFillImage: nil innerGlowAlpha: 0.2 isEtched: NO];
        [self drawThumbnailInContext: context];
        if (self.previewImage != nil) {
            [self drawTypeIconInContext: context];
        }
    } else {
        UIBezierPath * path = [self createBubblePathInRect: [self attachmentFrame]];
        [self drawBubblePath: path inRect: [self attachmentFrame] fillColor: fillColor strokeColor: strokeColor withFillImage: self.previewImage innerGlowAlpha: 0.3 isEtched: NO];

        switch (self.runButtonStyle) {
            case HXOBubbleRunButtonNone:
                break;
            case HXOBubbleRunButtonPlay:
                [self drawPlayButtonInContext: context];
                break;
        }
    }
}

- (void) drawThumbnailInContext: (CGContextRef) context {

    UIColor* thumbnailFrameColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 1];
    CGRect frame = [self attachmentFrame];

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

        UIImage * icon = self.attachmentTransferState == HXOAttachmentTranserStateDownloadPending ? [UIImage imageNamed: @"download-btn"] : self.largeAttachmentTypeIcon;
        CGPoint iconOrigin = CGPointMake(thumbnailFrameBounds.origin.x + 0.5 * thumbnailFrameBounds.size.width - 0.5 * icon.size.width,
                                         thumbnailFrameBounds.origin.y + 0.5 * thumbnailFrameBounds.size.height - 0.5 * icon.size.height);
        [icon drawAtPoint: iconOrigin];

    } else {
        CGRect imageFrame = [self thumbnailFrame: thumbnailFrameBounds];
        [self.previewImage drawInRect: imageFrame];
    }
    CGContextRestoreGState(context);
    [thumbnailFrameColor setStroke];
    thumbnailFramePath.lineWidth = 1;
    [thumbnailFramePath stroke];
}


- (void) drawTypeIconInContext: (CGContextRef) context {
    CGRect bubbleFrame = [self attachmentFrame];
    CGFloat x = bubbleFrame.origin.x + kHXOBubblePadding + 0.5 * (kHXOBubbleTypeIconSize - self.smallAttachmentTypeIcon.size.width) + (self.messageDirection == HXOMessageDirectionOutgoing ? kHXOBubbleMinimumHeight : kHXOBubblePadding);
    CGFloat y = bubbleFrame.origin.y + 0.5 * (bubbleFrame.size.height - self.smallAttachmentTypeIcon.size.height);
    CGPoint position = CGPointMake(x, y);
    [self.smallAttachmentTypeIcon drawAtPoint: position];
}

- (CGRect) runButtonFrame {
    CGRect frame = [self attachmentFrame];
    frame.origin.x += 0.5 * (frame.size.width - kHXOBubblePlayButtonSize);
    frame.origin.y += 0.5 * (frame.size.height - kHXOBubblePlayButtonSize);
    frame.size.width = kHXOBubblePlayButtonSize;
    frame.size.height = kHXOBubblePlayButtonSize;
    return frame;
}

- (void) drawPlayButtonInContext: (CGContextRef) context {
    //// Frames
    CGRect frame = [self runButtonFrame];

    //// Color Declarations
    UIColor* fillColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.9];
    UIColor* strokeColor = [UIColor colorWithRed: 0.404 green: 0.451 blue: 0.482 alpha: 1];

    //// Bezier 2 Drawing
    UIBezierPath* bezier2Path = [UIBezierPath bezierPath];
    [bezier2Path moveToPoint: CGPointMake(CGRectGetMinX(frame) + 19.75, CGRectGetMinY(frame) + 14.25)];
    [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 19.75, CGRectGetMinY(frame) + 35.25)];
    [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 34.75, CGRectGetMinY(frame) + 24.75)];
    [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 19.75, CGRectGetMinY(frame) + 14.25)];
    [bezier2Path closePath];
    [bezier2Path moveToPoint: CGPointMake(CGRectGetMinX(frame) + 41.82, CGRectGetMinY(frame) + 7.18)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 41.82, CGRectGetMinY(frame) + 41.82) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 51.39, CGRectGetMinY(frame) + 16.74) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 51.39, CGRectGetMinY(frame) + 32.26)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7.18, CGRectGetMinY(frame) + 41.82) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 32.26, CGRectGetMinY(frame) + 51.39) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 16.74, CGRectGetMinY(frame) + 51.39)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7.18, CGRectGetMinY(frame) + 7.18) controlPoint1: CGPointMake(CGRectGetMinX(frame) - 2.39, CGRectGetMinY(frame) + 32.26) controlPoint2: CGPointMake(CGRectGetMinX(frame) - 2.39, CGRectGetMinY(frame) + 16.74)];
    [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 41.82, CGRectGetMinY(frame) + 7.18) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 16.74, CGRectGetMinY(frame) - 2.39) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 32.26, CGRectGetMinY(frame) - 2.39)];
    [bezier2Path closePath];
    bezier2Path.lineJoinStyle = kCGLineJoinRound;

    [fillColor setFill];
    [bezier2Path fill];
    [strokeColor setStroke];
    bezier2Path.lineWidth = 1;
    [bezier2Path stroke];
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

- (CGRect) thumbnailFrame: (CGRect) thumbnailFrame {
    switch (self.thumbnailScaleMode) {
        case HXOThumbnailScaleModeStretchToFit:
            return thumbnailFrame;
        case HXOThumbnailScaleModeAspectFill: {
            CGSize imageSize = self.previewImage.size;
            CGFloat dx = imageSize.width - thumbnailFrame.size.width;
            CGFloat dy = imageSize.height - thumbnailFrame.size.height;
            CGFloat scale;
            if (dx < dy) {
                scale = thumbnailFrame.size.width / imageSize.width;
            } else {
                scale = thumbnailFrame.size.height / imageSize.height;
            }
            CGRect imageFrame = CGRectMake(thumbnailFrame.origin.x, thumbnailFrame.origin.y, imageSize.width * scale, imageSize.height * scale);
            imageFrame.origin.x -= 0.5 * (imageFrame.size.width - thumbnailFrame.size.width);
            imageFrame.origin.y -= 0.5 * (imageFrame.size.height - thumbnailFrame.size.height);
            return imageFrame;
        }
        case HXOThumbnailScaleModeActualSize: {
            CGSize imageSize = self.previewImage.size;
            return CGRectMake( thumbnailFrame.origin.x - 0.5 * (imageSize.width - thumbnailFrame.size.width) + 0.5, thumbnailFrame.origin.y - 0.5 * (imageSize.height - thumbnailFrame.size.height) + 0.5, imageSize.width, imageSize.height);
        }
    }
    
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
            CGFloat aspect = self.previewImage != nil ? self.previewImage.size.width / self.previewImage.size.height : self.imageAspect;
            bubbleHeight = imageWidth / aspect;
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

- (UIBezierPath*) thumbnailedBubblePathInRect: (CGRect) frame {
    UIBezierPath* thumbnailedBubblePathPath = [UIBezierPath bezierPath];

    if (self.messageDirection == HXOMessageDirectionIncoming) {
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


    } else {
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
        
    }
    return thumbnailedBubblePathPath;
}

- (CGRect) fillImageRectForImage: (UIImage*) image {
    if (self.attachmentStyle == HXOAttachmentStyleCropped16To9) {
        CGRect bubbleFrame = [self attachmentFrame];
        CGFloat dx = image.size.width - bubbleFrame.size.width;
        CGFloat dy = image.size.height - bubbleFrame.size.height;
        CGFloat scale;
        if (dx < dy) {
            scale = bubbleFrame.size.width / image.size.width;
        } else {
            scale = bubbleFrame.size.height / image.size.height;
        }
        CGRect imageFrame = CGRectMake(bubbleFrame.origin.x, bubbleFrame.origin.y, image.size.width * scale, image.size.height * scale);
        imageFrame.origin.x -= 0.5 * (imageFrame.size.width - bubbleFrame.size.width);
        imageFrame.origin.y -= 0.5 * (imageFrame.size.height - bubbleFrame.size.height);
        return imageFrame;
    }
    return [self attachmentFrame];
}

@end


@implementation AttachmentWithTextMessageCell

- (void) commonInit {
    [super commonInit];

    _textPartHeight = 40;

    _label = [self createMessageLabel];
}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    [super setColorScheme: colorScheme];
    [self configureTextColors: _label];
}

- (CGFloat) calculateHeightForWidth: (CGFloat) width {
    CGFloat attachmentHeight = [super calculateHeightForWidth: width];

    CGRect frame = CGRectMake(0, 0, [self textWidthForWidth: width], 10000);
    _label.frame = frame;
    CGSize textSize = [_label sizeThatFits: CGSizeMake([self textWidthForWidth: width], 0)];
    if (textSize.height <= 40) {
        attachmentHeight += 40;
    } else {
        attachmentHeight += textSize.height + 2 * kHXOBubblePadding;
    }
    return attachmentHeight;
}


- (CGRect) attachmentFrame {
    CGRect frame = [self bubbleFrame];
    frame.size.height -= _textPartHeight;
    return frame;
}

- (CGRect) textFrame {
    CGRect frame = [self lowerBubbleFrame];
    frame.size.width -= 3 * kHXOBubblePadding;
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x += 2 * kHXOBubblePadding;
    } else {
        frame.origin.x += kHXOBubblePadding;
    }
    return frame;
}

- (CGRect) lowerBubbleFrame {
    CGRect frame = [self bubbleFrame];
    frame.origin.y = frame.origin.y + (frame.size.height - _textPartHeight);
    frame.size.height = _textPartHeight;
    return frame;
}

- (void) layoutSubviews {
    [self layoutLabel: _label];

    if (_label.frame.size.height <= 40) {
        _textPartHeight = 40;
    } else {
        _textPartHeight = _label.frame.size.height + 2 * kHXOBubblePadding;
    }
    [super layoutSubviews];

    // TODO: improve this: currently layouts label twice :( 
    [self layoutLabel: _label];

}

- (void) drawRect:(CGRect)rect {
    //CGContextRef context = UIGraphicsGetCurrentContext();

    CGRect textBoxFrame = [self lowerBubbleFrame];
    textBoxFrame.origin.y -= kHXOBubbleBottomTextBoxOversize;
    textBoxFrame.size.height += kHXOBubbleBottomTextBoxOversize;
    UIBezierPath * p = [self bottomTextBoxPathInRect: textBoxFrame];
    [self drawBubblePath: p inRect: textBoxFrame fillColor: [self fillColor] strokeColor: [self strokeColor] withFillImage: nil innerGlowAlpha: 0.3 isEtched: self.colorScheme == HXOBubbleColorSchemeEtched];

    [super drawRect: rect];

    /*
    [[UIColor orangeColor] setStroke];
    UIBezierPath * path = [UIBezierPath bezierPathWithRect: [self textFrame]];
    [path stroke];

    path = [UIBezierPath bezierPathWithRect: [self attachmentFrame]];
    [path stroke];
     */
}

- (UIBezierPath*) bottomTextBoxPathInRect: (CGRect) frame {
    UIBezierPath* textBoxPath = [UIBezierPath bezierPath];
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        [textBoxPath moveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 1.5)];
        [textBoxPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMaxY(frame))];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMaxY(frame))];
        [textBoxPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 0.4)];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame))];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame))];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 1.5)];
        [textBoxPath closePath];
    } else {
        [textBoxPath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 1.5)];
        [textBoxPath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMaxY(frame))];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMaxY(frame))];
        [textBoxPath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 0.4)];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame))];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame))];
        [textBoxPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 1.5)];
        [textBoxPath closePath];
    }
    return textBoxPath;
}

@end