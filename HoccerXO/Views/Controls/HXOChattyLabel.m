//
//  HXOChattyLabel.m
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOChattyLabel.h"

#import <CoreText/CoreText.h>

//#define HXO_CHATTY_LABEL_DRAW_BOUNDING_BOX
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

@interface HXOChattyLabel ()
{
    NSAttributedString * _attributedText;
    NSMutableArray *     _tokenClasses;
    NSMutableArray *     _tokens;
    NSMutableArray *     _tokenButtons;

    CTFramesetterRef     _framesetter;
    CTFrameRef           _textFrame;
    CGAffineTransform    _textToViewTransform;
}
@end

@implementation HXOChattyLabel

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
}

- (void) tokenTapped: (UIButton*) sender {
    HXOCLToken * token = _tokens[sender.tag];
    [self.delegate chattyLabel: self didTapToken: token.match ofClass: token.tokenClass.classIdentifier];
}

- (void) setText:(NSString *)text {
    [super setText: text];
    [self createAttributedText: text];
}

- (void) registerTokenClass: (id) tokenClass withExpression: (NSRegularExpression*) regex style: (NSDictionary*) style {
    HXOCLTokenClass * tc = [[HXOCLTokenClass alloc] init];
    tc.classIdentifier = tokenClass;
    tc.regex = regex;
    tc.style = style;
    [_tokenClasses addObject: tc];
    [self createAttributedText: self.text];
}

- (void) createAttributedText: (NSString*) text {
    NSDictionary * fontAttributes = [self fontAttributes];
    NSMutableAttributedString * attributedText = [[NSMutableAttributedString alloc] initWithString: text attributes: fontAttributes];
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

- (void) layoutSubviews {
    if (_textFrame != NULL) {
        CFRelease(_textFrame);
    }
    UIBezierPath * framePath = [UIBezierPath bezierPathWithRect: self.bounds];
    _textFrame = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0,0), framePath.CGPath, 0);
    CGAffineTransform translateY = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
    CGAffineTransform mirrorY = CGAffineTransformMakeScale(1, -1);
    _textToViewTransform = CGAffineTransformConcat(mirrorY, translateY);

    [self setupTokenButtons];
}

- (void) setupTokenButtons {
    for (UIButton * button in _tokenButtons) {
        [button removeFromSuperview];
    }
    _tokenButtons = [NSMutableArray array];

    UIGraphicsBeginImageContext(CGSizeMake(1, 1));
    CGContextRef context = UIGraphicsGetCurrentContext();

    [self enumerateTokenRectsInContext: context usingBlock:^(NSUInteger tokenInex, CGRect rect) {

        rect = CGRectApplyAffineTransform(rect, _textToViewTransform);

        UIButton * button = [UIButton buttonWithType: UIButtonTypeCustom];
        [self addSubview: button];
        [button addTarget: self action:@selector(tokenTapped:) forControlEvents:UIControlEventTouchUpInside];
        button.frame = rect;
#ifdef HXO_CHATTY_LABEL_SHOW_BUTTONS
        button.backgroundColor = [UIColor colorWithWhite: 0.5 alpha: 0.5];
#endif
        button.tag = tokenInex;
        [_tokenButtons addObject: button];
    }];
    UIGraphicsEndImageContext();
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
#ifdef HXO_CHATTY_LABEL_DRAW_BOUNDING_BOX
    [[UIColor colorWithWhite: 0.9 alpha: 1.0] setFill];
    CGContextFillRect(context, self.bounds);
#endif

	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextConcatCTM(context, _textToViewTransform);

#ifdef HXO_CHATTY_LABEL_DRAW_TOKEN_RECTS
    [[UIColor orangeColor] setFill];
    [self enumerateTokenRectsInContext: context usingBlock: ^(NSUInteger tokenInex, CGRect rect) {
        CGContextFillRect(context, rect);
    }];
#endif

	CTFrameDraw(_textFrame, context);
}

- (void) enumerateTokenRectsInContext: (CGContextRef) context usingBlock: (void(^)(NSUInteger tokenInex, CGRect rect)) block {
    CFArrayRef lines = CTFrameGetLines(_textFrame);
    CGPoint *origins = malloc(sizeof(CGPoint)*[(__bridge NSArray *)lines count]);
    CTFrameGetLineOrigins(_textFrame, CFRangeMake(0, 0), origins);
    NSInteger lineIndex = 0;
    for (id oneLine in (__bridge NSArray *)lines) {
        CFArrayRef runs = CTLineGetGlyphRuns((__bridge CTLineRef)oneLine);
        CGRect lineBounds = CTLineGetImageBounds((__bridge CTLineRef)oneLine, context);

        lineBounds.origin.x += origins[lineIndex].x;
        lineBounds.origin.y += origins[lineIndex].y;
        lineIndex++;
        CGFloat offset = 0;

        for (id oneRun in (__bridge NSArray *)runs) {
            CGFloat ascent = 0;
            CGFloat descent = 0;

            CGFloat width = CTRunGetTypographicBounds((__bridge CTRunRef) oneRun,
                                                      CFRangeMake(0, 0),
                                                      &ascent,
                                                      &descent, NULL);

            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) oneRun);

            NSNumber * tokenIndex = [attributes objectForKey: kHXOChattyLabelTokenIndexAttributeName];

            if (tokenIndex != nil) {
                CGRect bounds = CGRectMake(lineBounds.origin.x + offset,
                                           lineBounds.origin.y,
                                           width, ascent + descent);

                // don't draw too far to the right
                if (bounds.origin.x + bounds.size.width > CGRectGetMaxX(lineBounds)) {
                    bounds.size.width = CGRectGetMaxX(lineBounds) - bounds.origin.x;
                }

                block([tokenIndex unsignedIntegerValue], bounds);
                
            }
            
            offset += width;
        }
    }
    
    // cleanup
    free(origins);
}

- (void) dealloc {
    if (_framesetter != NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
    if (_framesetter != NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
}

@end

@implementation HXOCLTokenClass
@end

@implementation HXOCLToken
@end
