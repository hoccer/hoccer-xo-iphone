//
//  HXOChattyLabel.m
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOLinkyLabel.h"

#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

//#define HXO_CHATTY_LABEL_DRAW_TOKEN_RECTS
//#define HXO_CHATTY_LABEL_SHOW_BUTTONS

static NSDictionary* ourDefaultStyle;
static const NSString * kHXOChattyLabelTokenIndexAttributeName = @"HXOChattyLabelTokenIndex";

@interface HXOCLTokenClass : NSObject

@property (nonatomic,strong) id classIdentifier;
@property (nonatomic,strong) NSRegularExpression * regex;
@property (nonatomic,strong) NSDictionary * style;

@end

@interface HXOCLToken : NSObject

@property (nonatomic,strong) HXOCLTokenClass * tokenClass;
@property (nonatomic,strong) NSTextCheckingResult * match;

@end

@interface HXOLinkyLabel ()
{
    NSAttributedString * _attributedText;
    NSMutableArray *     _tokenClasses;
    NSMutableArray *     _tokens;
    NSDictionary *       _tokenRects;

    CTFramesetterRef     _framesetter;
    CTFrameRef           _textFrame;
    CGAffineTransform    _textToViewTransform;

    HXOCLToken *         _tappedToken;
}
@end

@implementation HXOLinkyLabel

#pragma mark - Con- and Destruction

+ (void) initialize {
    ourDefaultStyle = @{(id)kCTForegroundColorAttributeName: (id)[UIColor blueColor].CGColor};
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    _tokenClasses = [NSMutableArray array];
    _defaultTokenStyle = ourDefaultStyle;
    [self createAttributedText: self.text];
    self.userInteractionEnabled = YES;

    self.layer.shadowOpacity = 0.0;
    self.layer.shadowRadius = 0.0;

    self.clearsContextBeforeDrawing = YES;
}

- (void) dealloc {
    if (_textFrame != NULL) {
        CFRelease(_textFrame);
        _textFrame = NULL;
    }
    if (_framesetter != NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
}

#pragma mark - Public API

- (void) setText:(NSString *)text {
    [super setText: text];
    [self createAttributedText: text];
    [self setNeedsLayout];
}

- (void) setTextColor:(UIColor *)textColor {
    [super setTextColor: textColor];
    [self createAttributedText: self.text];
    [self setNeedsLayout];
}

- (void) registerTokenClass: (id) tokenClass withExpression: (NSRegularExpression*) regex style: (NSDictionary*) style {
    HXOCLTokenClass * tc = [[HXOCLTokenClass alloc] init];
    tc.classIdentifier = tokenClass;
    tc.regex = regex;
    tc.style = style;
    [_tokenClasses addObject: tc];
    [self createAttributedText: self.text];
}

- (CGSize) sizeThatFits:(CGSize)size {
    if (self.numberOfLines == 0) {
        size.height = 0;
    }
    CGSize fittingSize = CTFramesetterSuggestFrameSizeWithConstraints(_framesetter, CFRangeMake(0, 0), NULL, size, NULL);
    /*
    if (fittingSize.width < size.width) {
        fittingSize.width = size.width;
    }*/
    fittingSize.width = ceilf(fittingSize.width);
    //fittingSize.height = ceilf(fittingSize.height);
    return fittingSize;
}

- (NSUInteger) currentNumberOfLines {
    if (_framesetter == NULL) {
        return 0;
    }
    if (_textFrame == NULL) {
        [self updateTextFrame];
    }
    CFArrayRef lines = CTFrameGetLines(_textFrame);
    return ((__bridge NSArray*)lines).count;
}

- (void) setShadowColor:(UIColor *)shadowColor {
    if (shadowColor != nil) {
        self.layer.shadowOpacity = 1.0;
    }
    self.layer.shadowColor = shadowColor.CGColor;
}

- (UIColor*) shadowColor {
    return [UIColor colorWithCGColor: self.layer.shadowColor];
}

- (void) setShadowOffset:(CGSize)shadowOffset {
    self.layer.shadowOffset = shadowOffset;
}

- (CGSize) shadowOffset {
    return self.layer.shadowOffset;
}

#pragma mark - Layout and Drawing

- (void) createAttributedText: (NSString*) text {
    if (_framesetter != NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }

    if (text == nil) {
        return;
    }
    NSMutableDictionary * paragraphAttributes = [NSMutableDictionary dictionaryWithDictionary: [self fontAttributes]];
    [paragraphAttributes setObject: (__bridge id)[self paragraphStyle] forKey: (__bridge id)kCTParagraphStyleAttributeName];
    if (self.textColor != nil) {
        [paragraphAttributes setObject: (id)self.textColor.CGColor forKey: (id)kCTForegroundColorAttributeName];
    }

    NSMutableAttributedString * attributedText = [[NSMutableAttributedString alloc] initWithString: text attributes: paragraphAttributes];
    [self tokenize: attributedText];
    _attributedText = attributedText;
    _framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedText);
}

- (void) tokenize: (NSMutableAttributedString*) attributedText {
    _tokens = [NSMutableArray array];
    for (HXOCLTokenClass* tokenClass in _tokenClasses) {
        NSDictionary * style = tokenClass.style != nil ? tokenClass.style : self.defaultTokenStyle;
        NSArray * matches = [tokenClass.regex matchesInString: self.text options: 0 range: NSMakeRange(0, self.text.length)];
        for (NSTextCheckingResult * match in matches) {
            NSMutableDictionary * attributes = [NSMutableDictionary dictionaryWithDictionary: style];
            [attributes addEntriesFromDictionary: [self fontAttributes]];
            [attributes setObject: @(_tokens.count) forKey: kHXOChattyLabelTokenIndexAttributeName];
            [attributedText setAttributes: attributes range: match.range];
            HXOCLToken * token = [[HXOCLToken alloc] init];
            token.tokenClass = tokenClass;
            token.match = match;
            [_tokens addObject: token];
        }
    }
}

- (NSDictionary*) fontAttributes {
    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)(self.font.fontName), self.font.pointSize, NULL);
    return @{(id)kCTFontAttributeName: (__bridge id)font};
}

- (CTParagraphStyleRef) paragraphStyle {
    static const NSUInteger count = 2;
    CTParagraphStyleSetting * settings = malloc(sizeof(CTParagraphStyleSetting) * count);
    CTTextAlignment alignment;
    switch (self.textAlignment) {
        case NSTextAlignmentLeft:      alignment = kCTTextAlignmentLeft;      break;
        case NSTextAlignmentRight:     alignment = kCTTextAlignmentRight;     break;
        case NSTextAlignmentCenter:    alignment = kCTTextAlignmentCenter;    break;
        case NSTextAlignmentJustified: alignment = kCTTextAlignmentJustified; break;
        case NSTextAlignmentNatural:   alignment = kCTTextAlignmentNatural;   break;
    }
    settings[0].spec = kCTParagraphStyleSpecifierAlignment;
    settings[0].value = & alignment;
    settings[0].valueSize = sizeof(alignment);

    CTLineBreakMode lineBreakMode;
    switch (self.lineBreakMode) {
        case NSLineBreakByCharWrapping:     lineBreakMode = kCTLineBreakByCharWrapping;     break;
        case NSLineBreakByClipping:         lineBreakMode = kCTLineBreakByClipping;         break;
        case NSLineBreakByTruncatingHead:   lineBreakMode = kCTLineBreakByTruncatingHead;   break;
        case NSLineBreakByTruncatingMiddle: lineBreakMode = kCTLineBreakByTruncatingMiddle; break;
        case NSLineBreakByTruncatingTail:   lineBreakMode = kCTLineBreakByTruncatingTail;   break;
        case NSLineBreakByWordWrapping:     lineBreakMode = kCTLineBreakByWordWrapping;     break;
    }
    settings[1].spec = kCTParagraphStyleSpecifierLineBreakMode;
    settings[1].value = & lineBreakMode;
    settings[1].valueSize = sizeof(lineBreakMode);

    // TODO: apply more attributes like line spacing, &c.
    
    CTParagraphStyleRef style = CTParagraphStyleCreate(settings, count);
    free(settings);
    return style;
}

- (void) layoutSubviews {
    if (_textFrame != NULL) {
        CFRelease(_textFrame);
    }
    [self updateTextFrame];

    [self setNeedsDisplay];
}

- (void) updateTextFrame {
    if (_framesetter != NULL) {
        UIBezierPath * framePath = [UIBezierPath bezierPathWithRect: self.bounds];
        _textFrame = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0,0), framePath.CGPath, 0);
    }
    CGAffineTransform translateY = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
    CGAffineTransform mirrorY = CGAffineTransformMakeScale(1, -1);
    _textToViewTransform = CGAffineTransformConcat(mirrorY, translateY);

    _tokenRects = nil;
}

- (NSDictionary*) createTokenRectsInContext: (CGContextRef) context {
    NSMutableDictionary * rects = [NSMutableDictionary dictionaryWithCapacity: [_tokens count]];
    [self enumerateTokenRectsInContext: context usingBlock:^(NSUInteger tokenInex, CGRect rect) {
        rect = CGRectApplyAffineTransform(rect, _textToViewTransform);
        NSValue * rectValue = [NSValue valueWithCGRect: rect];
        HXOCLToken * token = _tokens[tokenInex];
        [rects setObject: token forKey: rectValue];
    }];
    return rects;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSaveGState(context);

    if (_tokenRects == nil) {
        _tokenRects = [self createTokenRectsInContext: context];
    }

    if (self.backgroundColor != nil) {
        [self.backgroundColor setFill];
        CGContextFillRect(context, self.bounds);
    }

	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextConcatCTM(context, _textToViewTransform);

#ifdef HXO_CHATTY_LABEL_DRAW_TOKEN_RECTS
    [[UIColor orangeColor] setFill];
    [self enumerateTokenRectsInContext: context usingBlock: ^(NSUInteger tokenInex, CGRect rect) {
        CGContextFillRect(context, rect);
    }];
#endif

    if (_textFrame != NULL) {
        CTFrameDraw(_textFrame, context);
    }

    CGContextRestoreGState(context);
}

- (void) enumerateTokenRectsInContext: (CGContextRef) context usingBlock: (void(^)(NSUInteger tokenInex, CGRect rect)) block {
    if (_textFrame == NULL) {
        return;
    }
    CFArrayRef lines = CTFrameGetLines(_textFrame);
    CGPoint *origins = malloc(sizeof(CGPoint)*[(__bridge NSArray *)lines count]);
    CTFrameGetLineOrigins(_textFrame, CFRangeMake(0, 0), origins);
    NSInteger lineIndex = 0;
    for (id line in (__bridge NSArray *)lines) {
        CFArrayRef runs = CTLineGetGlyphRuns((__bridge CTLineRef)line);
        CGRect lineBounds = CTLineGetImageBounds((__bridge CTLineRef)line, context);

        lineBounds.origin.x += origins[lineIndex].x;
        lineBounds.origin.y += origins[lineIndex].y;
        CGFloat offset = 0;

        for (id run in (__bridge NSArray *)runs) {
            CGFloat ascent = 0;
            CGFloat descent = 0;

            CGFloat width = CTRunGetTypographicBounds((__bridge CTRunRef) run,
                                                      CFRangeMake(0, 0),
                                                      &ascent,
                                                      &descent, NULL);

            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) run);

            NSNumber * tokenIndex = [attributes objectForKey: kHXOChattyLabelTokenIndexAttributeName];

            if (tokenIndex != nil) {
                // TODO: improve link rect placement
                CGFloat lineHeight = lineIndex > 0 ? (origins[lineIndex - 1].y - origins[lineIndex].y) : self.bounds.size.height - origins[lineIndex].y;
                CGRect bounds = CGRectMake(lineBounds.origin.x + offset,
                                           lineBounds.origin.y,
                                           width, /*ascent + descent*/ lineHeight);
                if (bounds.origin.x + bounds.size.width > CGRectGetMaxX(lineBounds)) {
                    bounds.size.width = CGRectGetMaxX(lineBounds) - bounds.origin.x;
                }

                block([tokenIndex unsignedIntegerValue], bounds);
                
            }
            
            offset += width;
        }
        lineIndex++;
    }
    // cleanup
    free(origins);
}

#pragma mark - Touch Event Handling

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (NSValue * rectValue in _tokenRects) {
        CGRect rect = [rectValue CGRectValue];
        UITouch * touch = [[event touchesForView: self] anyObject];
        if (CGRectContainsPoint(rect, [touch locationInView: self])) {
            HXOCLToken * token = _tokenRects[rectValue];
            [self.delegate chattyLabel: self didTapToken: token.match ofClass: token.tokenClass.classIdentifier];
            break;
        }
    }
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
}

@end

@implementation HXOCLTokenClass
@end

@implementation HXOCLToken
@end
