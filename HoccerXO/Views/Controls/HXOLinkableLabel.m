//
//  HXOLinkableLabel.m
//  HoccerXO
//
//  Created by David Siegel on 03.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOLinkableLabel.h"

#import "NSString+Emojis.h"

@interface HXOClickableToken : NSObject

@property (nonatomic, strong) id tokenClass;
@property (nonatomic, strong) NSString * token;

@end

@implementation HXOLinkableLabel

@dynamic enabled;
@dynamic font;
@dynamic highlighted;
@dynamic highlightedTextColor;
@dynamic lineBreakMode;
@dynamic numberOfLines;
@dynamic text;
@dynamic textAlignment;
@dynamic textColor;
@dynamic userInteractionEnabled;

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self != nil) {
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
    _label = [[UILabel alloc] initWithFrame:self.bounds];
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _label.backgroundColor = self.backgroundColor;
    _label.numberOfLines = 0;
    [self addSubview: _label];
}

- (NSDictionary*) defaultLinkExpressions {
    NSError * error = nil;
    // found at http://regexlib.com/REDetails.aspx?regexp_id=96
    NSRegularExpression * httpRegex = [NSRegularExpression regularExpressionWithPattern: @"(http|https)://[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&amp;:/~\\+#]*[\\w\\-\\@?^=%&amp;/~\\+#])?"
                                                                                options: NSRegularExpressionCaseInsensitive error: & error];
    // TODO: error handling;
    return @{@"web": httpRegex};
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self removeButtons];
    [self createClickableTokens];
}

- (void) setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor: [UIColor orangeColor] /*backgroundColor*/];
    [_label setBackgroundColor: backgroundColor];
}

- (CGSize) sizeThatFits:(CGSize)size {
    return [_label sizeThatFits: size];
}

- (void) setText: (NSString*) text {
    // apply the labels font to the whole text
    NSMutableAttributedString * attributedText = [[NSMutableAttributedString alloc] initWithString: text attributes: @{NSFontAttributeName: self.font}];

    [self scanTokensInText: text andApplyHighlightingTo: (NSMutableAttributedString*) attributedText];

    if (self.emojiScale != 0) {
        [self applyEmojiFont: text attributedText: attributedText];
    }

    _label.attributedText = attributedText;
}

- (void) applyEmojiFont: (NSString*) text attributedText: (NSMutableAttributedString*) attributedText {

    UIFont * emojiFont = [UIFont fontWithName:@"AppleColorEmoji" size: self.emojiScale * _label.font.pointSize];
    NSLog(@"emoji lineheight %f", emojiFont.lineHeight);
    NSDictionary * emojiAttributes = @{NSFontAttributeName: emojiFont};
    [text enumerateEmojiRangesUsingBlock:^(NSRange emojiRange) {
        //NSLog(@"==== emoji range %@", NSStringFromRange(emojiRange));
        [attributedText addAttributes: emojiAttributes range: emojiRange];
    }];
}

- (void) scanTokensInText: text andApplyHighlightingTo: (NSMutableAttributedString*) attributedText {
    NSDictionary * expressions = nil;
    if ([self.delegate respondsToSelector: @selector(linkClassExpressionsForLabel:)]) {
        expressions = [self.delegate linkClassExpressionsForLabel: self];
    } else {
        expressions = [self defaultLinkExpressions];
    }

    NSMutableArray * tokens = [[NSMutableArray alloc] init];

    for (id tokenClass in expressions) {
        NSRegularExpression * regex = expressions[tokenClass];
        NSArray *matches = [regex matchesInString: text
                                          options: 0
                                            range: NSMakeRange(0, [text length])];
        for (NSTextCheckingResult *match in matches) {
            [tokens addObject: match];
            NSDictionary * attributes;
            if ([self.delegate respondsToSelector:@selector(label:stringAttributesForClass:)]) {
                attributes = [self.delegate label: self stringAttributesForClass: tokenClass];
            } else {
                attributes = [self defaultAttributes];
            }
            [attributedText setAttributes: attributes range: [match range]];
        }
    }
    _tokens = tokens;
}

#pragma mark - Button Handling

- (void) createClickableTokens {
    NSArray * sizeChart = [self createSizeChart];
}

- (NSArray*) createSizeChart {
    NSMutableArray * lines = [[NSMutableArray alloc] init];
    NSAttributedString * text = _label.attributedText;
    NSUInteger length = [text length];
    CGSize size = CGSizeZero;

    NSLog(@"lineheight %f", _label.font.lineHeight);

    NSStringDrawingContext * context = [[NSStringDrawingContext alloc] init];
    
    for (NSUInteger i = 1; i < length; ++i) {
        NSRange range = NSMakeRange(0, i);
        size = [[text attributedSubstringFromRange: range] boundingRectWithSize: _label.bounds.size options: NSStringDrawingUsesLineFragmentOrigin context:context].size;
        NSLog(@"size: %d %@", i, NSStringFromCGSize(size));
    }

    return lines;
}

- (NSDictionary*) defaultAttributes {
    return @{NSForegroundColorAttributeName: [UIColor blueColor]};
}

- (void) createButtonWithText: (NSString*) text withFrame: (CGRect) frame withTag: (NSInteger) tag {
    UIButton * button = [UIButton buttonWithType: UIButtonTypeCustom];
    button.frame = frame;
    button.tag = tag;
    [button setTitle: text forState: UIControlStateNormal];
}

- (void) removeButtons {
    for (UIButton * button in _buttons) {
        [button removeFromSuperview];
    }
}

#pragma mark - Label Forward Invocations

- (void) forwardInvocation: (NSInvocation*) invocation {
	SEL selector = [invocation selector];
	if ([_label respondsToSelector: selector]) {
		[invocation invokeWithTarget: _label];
	} else {
		[self doesNotRecognizeSelector: selector];
	}
}

- (NSMethodSignature* )methodSignatureForSelector: (SEL) selector {
	NSMethodSignature* methodSignature = [super methodSignatureForSelector: selector];
	if (methodSignature == nil) {
		methodSignature = [_label methodSignatureForSelector: selector];
	}
	return methodSignature;
}

- (BOOL) respondsToSelector: (SEL) selector {
	return [super respondsToSelector: selector] || [_label respondsToSelector: selector];
}

@end

@implementation HXOClickableToken
@end