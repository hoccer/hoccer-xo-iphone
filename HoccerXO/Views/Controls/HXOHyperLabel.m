//
//  HXOHyperLabel.m
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOHyperLabel.h"

NSString * kHXOLinkAttributeName = @"HXOHyperLabelLink";

@implementation NSMutableAttributedString (HXOHyperLabel)

- (void) addLinksMatching:(NSRegularExpression *)regex {
    NSArray * matches = [regex matchesInString: self.string options: 0 range: NSMakeRange(0, self.length)];
    for (NSTextCheckingResult * match in matches) {
        [self setAttributes: @{kHXOLinkAttributeName: match} range: match.range];
    }
}

@end

@interface HXOHyperLabel ()

@property (nonatomic,readonly) CTFramesetterRef  framesetter;
@property (nonatomic,readonly) CTFrameRef        textFrame;
@property (nonatomic,readonly) CTFontRef         ctfont;
@property (nonatomic,strong)   NSDictionary*     links;
@property (nonatomic,assign)   CGAffineTransform textToViewTransform;

@end

@implementation HXOHyperLabel

@synthesize framesetter = _framesetter;
@synthesize textFrame   = _textFrame;
@synthesize ctfont      = _ctfont;

- (id)initWithFrame:(CGRect)frame {
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
    self.textAlignment = NSTextAlignmentNatural;
    self.lineBreakMode = NSLineBreakByWordWrapping;
    self.textToViewTransform = CGAffineTransformIdentity;
    self.linkColor = [UIColor blueColor];

    [self addGestureRecognizer: [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(tapped:)]];
    [self addGestureRecognizer: [[UILongPressGestureRecognizer alloc] initWithTarget: self action:@selector(tapped:)]];

    self.contentMode = UIViewContentModeRedraw;

}

- (void) setAttributedText:(NSAttributedString *)attributedText {
    if ( ! [_attributedText isEqual: attributedText]) {
        _attributedText = attributedText;
        [self releaseFramesetter];
        [self setNeedsLayout];
    }
}

- (void) setFont:(UIFont *)font {
    if ( ! [_font isEqual: font]) {
        _font = font;
        [self releaseCTFont];
        [self setNeedsLayout];
    }
}

- (void) setTextColor:(UIColor *)textColor {
    if ( ! [_textColor isEqual: textColor]) {
        _textColor = textColor;
        [self releaseFramesetter];
        [self setNeedsLayout];
    }
}

- (void) setLinkColor:(UIColor *)linkColor {
    if ( ! [_linkColor isEqual: linkColor]) {
        _linkColor = linkColor;
        //[self releaseFramesetter];
        //[self setNeedsLayout];
        [self setNeedsDisplay];
    }
}

- (void) setTextAlignment:(NSTextAlignment)textAlignment {
    if (textAlignment != _textAlignment) {
        _textAlignment = textAlignment;
        [self setNeedsLayout];
    }
}

- (void) setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    if (lineBreakMode != _lineBreakMode) {
        _lineBreakMode = lineBreakMode;
        [self setNeedsLayout];
    }
}

#pragma mark - Drawing and Layout

- (CGSize) sizeThatFits:(CGSize)size {
    size.height = 0;
    CGSize fittingSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetter, CFRangeMake(0, 0), NULL, size, NULL);
    fittingSize.width = ceilf(fittingSize.width);
    //fittingSize.height = ceilf(fittingSize.height);
    return fittingSize;
}

- (void) layoutSubviews {
    [self releaseTextFrame];
    CGFloat dx = 0.5 * (self.bounds.size.height - [self sizeThatFits: self.bounds.size].height);
    CGAffineTransform translateY = CGAffineTransformMakeTranslation(0, self.bounds.size.height + dx);
    CGAffineTransform mirrorY = CGAffineTransformMakeScale(1, -1);
    self.textToViewTransform = CGAffineTransformConcat(mirrorY, translateY);
    [self setNeedsDisplay]; // XXX labels are occasionally empty... try to trap this
}

- (void) drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.textFrame) {
        CGContextSaveGState(context);

        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextConcatCTM(context, self.textToViewTransform);

        CTFrameDraw(self.textFrame, context);

        CGContextRestoreGState(context);

        [self updateLinkRects: context];
    }
}

#pragma mark - Touch Event Handling

- (void) tapped: (UITapGestureRecognizer*) sender {
    if (self.delegate && sender.state == UIGestureRecognizerStateEnded) {
        for (NSValue * rectValue in self.links.allKeys) {
            CGRect rect = [rectValue CGRectValue];
            if (CGRectContainsPoint(rect, [sender locationInView: self])) {
                id link = self.links[rectValue];
                BOOL isLongPress = [sender isKindOfClass: [UILongPressGestureRecognizer class]];
                [self.delegate hyperLabel: self didPressLink: link long: isLongPress];
                break;
            }
        }

    }
}

-(id)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    for (NSValue * rectValue in self.links.allKeys) {
        CGRect rect = [rectValue CGRectValue];
        if (CGRectContainsPoint(rect, point)) {
            return self;
        }
    }

    return nil;
}

- (void) updateLinkRects: (CGContextRef) context {
    if ( ! self.links) {
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);

        NSMutableDictionary * links = [NSMutableDictionary dictionary];
        CFArrayRef lines = CTFrameGetLines(self.textFrame);
        CGPoint *origins = malloc(sizeof(CGPoint)*[(__bridge NSArray *)lines count]);
        CTFrameGetLineOrigins(self.textFrame, CFRangeMake(0, 0), origins);
        NSInteger lineIndex = 0;
        for (id line in (__bridge NSArray *)lines) {
            CFArrayRef runs = CTLineGetGlyphRuns((__bridge CTLineRef)line);
            CGRect lineBounds = CTLineGetImageBounds((__bridge CTLineRef)line, context);

            lineBounds.origin.x += origins[lineIndex].x;
            lineBounds.origin.y += origins[lineIndex].y;
            CGFloat x = 0;

            for (id run in (__bridge NSArray *)runs) {
                CGFloat width = CTRunGetTypographicBounds((__bridge CTRunRef) run,
                                                          CFRangeMake(0, 0),
                                                          NULL,
                                                          NULL, NULL);

                NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) run);

                id link = [attributes objectForKey: kHXOLinkAttributeName];

                if (link != nil) {
                    CGFloat lineHeight = lineIndex > 0 ? (origins[lineIndex - 1].y - origins[lineIndex].y) : self.bounds.size.height - origins[lineIndex].y;
                    CGRect bounds = CGRectMake(lineBounds.origin.x + x,
                                               lineBounds.origin.y,
                                               width, lineHeight);
                    if (bounds.origin.x + bounds.size.width > CGRectGetMaxX(lineBounds)) {
                        bounds.size.width = CGRectGetMaxX(lineBounds) - bounds.origin.x;
                    }
                    bounds = CGRectApplyAffineTransform(bounds, self.textToViewTransform);
                    [links setObject: link forKey: [NSValue valueWithCGRect: bounds]];
                }

                x += width;
            }
            lineIndex++;
        }
        // cleanup
        free(origins);
        self.links = [NSDictionary dictionaryWithDictionary: links];
    }
}

#pragma mark - Font and Paragraph Attribute Handling

- (NSDictionary*) globalAttributes {
    NSMutableDictionary * attributes = [NSMutableDictionary dictionary];
    if (self.ctfont) {
        [attributes setObject: (id)self.ctfont forKey: (id)kCTFontAttributeName];
    }
    if (self.textColor) {
        [attributes setObject: (id)self.textColor.CGColor forKey: (id)kCTForegroundColorAttributeName];
    }
    [attributes setObject: (id)[self paragraphStyle] forKey: (id)kCTParagraphStyleAttributeName];
    return attributes;
}


- (CTParagraphStyleRef) paragraphStyle {
    static const NSUInteger count = 2;
    CTParagraphStyleSetting * settings = malloc(sizeof(CTParagraphStyleSetting) * count);
    CTTextAlignment alignment = [self ctTextAlignment];
    settings[0].spec = kCTParagraphStyleSpecifierAlignment;
    settings[0].value = & alignment;
    settings[0].valueSize = sizeof(alignment);

    CTLineBreakMode lineBreakMode = [self ctLineBreakMode];
    settings[1].spec = kCTParagraphStyleSpecifierLineBreakMode;
    settings[1].value = & lineBreakMode;
    settings[1].valueSize = sizeof(lineBreakMode);

    // TODO: apply more attributes like line spacing, &c.

    CTParagraphStyleRef style = CTParagraphStyleCreate(settings, count);
    free(settings);
    return style;
}

- (CTTextAlignment) ctTextAlignment {
    switch (self.textAlignment) {
        case NSTextAlignmentLeft:      return kCTTextAlignmentLeft;
        case NSTextAlignmentRight:     return kCTTextAlignmentRight;
        case NSTextAlignmentCenter:    return kCTTextAlignmentCenter;
        case NSTextAlignmentJustified: return kCTTextAlignmentJustified;
        case NSTextAlignmentNatural:   return kCTTextAlignmentNatural;
    }
}

- (CTLineBreakMode) ctLineBreakMode {
    switch (self.lineBreakMode) {
        case NSLineBreakByCharWrapping:     return kCTLineBreakByCharWrapping;
        case NSLineBreakByClipping:         return kCTLineBreakByClipping;
        case NSLineBreakByTruncatingHead:   return kCTLineBreakByTruncatingHead;
        case NSLineBreakByTruncatingMiddle: return kCTLineBreakByTruncatingMiddle;
        case NSLineBreakByTruncatingTail:   return kCTLineBreakByTruncatingTail;
        case NSLineBreakByWordWrapping:     return kCTLineBreakByWordWrapping;
    }
}

- (CTFrameRef) textFrame {
    if ( ! _textFrame && self.framesetter) {
        _textFrame = CTFramesetterCreateFrame(self.framesetter, CFRangeMake(0,0), [UIBezierPath bezierPathWithRect: self.bounds].CGPath, NULL);
        self.links = nil;
    }
    return _textFrame;
}

- (CTFramesetterRef) framesetter {
    if ( ! _framesetter && self.attributedText) {
        NSMutableAttributedString * string = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedText];
        [string addAttributes: [self globalAttributes] range: NSMakeRange(0, string.length)];
        [self applyLinkColor: string];


        _framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)(string));
    }
    return _framesetter;
}

- (void) applyLinkColor: (NSMutableAttributedString*) string {
    [string enumerateAttribute:kHXOLinkAttributeName inRange: NSMakeRange(0, string.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value) {
            [string addAttributes: @{(id)kCTForegroundColorAttributeName: (id)self.linkColor.CGColor} range: range];
        }
    }];
}

- (CTFontRef) ctfont {
    if ( ! _ctfont && self.font) {
        _ctfont = CTFontCreateWithName((__bridge CFStringRef)(self.font.fontName), self.font.pointSize, NULL);
    }
    return _ctfont;
}

- (void) releaseTextFrame {
    if (_textFrame) {
        CFRelease(_textFrame);
        _textFrame = NULL;
    }
}

- (void) releaseFramesetter {
    [self releaseTextFrame];
    if (_framesetter) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
}
- (void) releaseCTFont {
    [self releaseFramesetter];
    if (_ctfont) {
        CFRelease(_ctfont);
        _ctfont = NULL;
    }
}

- (void) dealloc {
    [self releaseFramesetter];
}

@end
