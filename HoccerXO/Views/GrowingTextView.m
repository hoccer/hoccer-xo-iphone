//
//  AttachmentViewFactory.h
//  HoccerXO
//
//  Created by David Siegel on 20.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

// Based on http://www.hanspinckaers.com/multi-line-uitextview-similar-to-sms

#import "GrowingTextView.h"

@interface GrowingTextView ()
{
	CGFloat _minHeight;
    CGFloat _singleLineContentHeight;
	id<UITextViewDelegate,GrowingTextViewDelegate> __unsafe_unretained delegate;
}

-(void)commonInitialiser;
-(void)resizeTextView:(CGFloat)newSizeH;
-(void)growDidStop;
-(CGFloat)probeHeightForLineCount:(NSInteger) lineCount;
-(void)animateTextViewToHeight:(CGFloat) newViewHeight;
-(void) observeTextDidChange: (BOOL) flag;
@end

@implementation GrowingTextView

- (id) initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInitialiser];
    }
    return self;
}

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInitialiser];
    }
    return self;
}

- (void) dealloc {
    [self observeTextDidChange: NO];
}

- (void) commonInitialiser {
    [self observeTextDidChange: YES];
    self.scrollEnabled = NO;
    UIEdgeInsets insets = self.contentInset;
    insets.top = 0;
    insets.bottom = 0;
    self.contentInset = insets;
    self.showsHorizontalScrollIndicator = NO;
    _animateHeightChange = YES;
    _minHeight = self.frame.size.height;
    _maxHeight = 100;
    _singleLineContentHeight = self.font.lineHeight + 16.0;
}

- (CGSize) sizeThatFits:(CGSize)size {
    if (size.height < _minHeight) {
        size.height = _minHeight;
    }
    return size;
}

- (void) layoutSubviews {
    [super layoutSubviews];

    /* TODO: add padding?
	CGRect r = self.bounds;
	r.origin.y = 0;
	r.origin.x = padding.left;
    r.size.width -= padding.left + padding.right;
    
    internalTextView.frame = r;
     */
}

/*
-(void)setPadding:(UIEdgeInsets)inset
{
    padding = inset;
    
    CGRect r = self.frame;
    r.origin.y = inset.top - inset.bottom;
    r.origin.x = inset.left;
    r.size.width -= inset.left + inset.right;
    
    internalTextView.frame = r;
    
    [self setMaxNumberOfLines:maxNumberOfLines];
    [self setMinNumberOfLines:minNumberOfLines];
}

-(UIEdgeInsets)padding
{
    return padding;
}
*/

- (void) observeTextDidChange: (BOOL) flag {
    if (flag) {
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(textViewDidChange:)
													 name:UITextViewTextDidChangeNotification
												   object: self];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (CGFloat) probeHeightForLineCount:(NSInteger) lineCount {

    NSString *testText = @"-";
    for (NSInteger i = 1; i < lineCount; ++i) {
        testText = [testText stringByAppendingString:@"\n|W|"];
    }
#ifdef PRE_IOS7
    return [testText sizeWithFont: self.font
                constrainedToSize: CGSizeMake(self.contentSize.width, 1000000)
                   lineBreakMode :NSLineBreakByWordWrapping].height;
#else
    CGSize constraint = CGSizeMake(self.contentSize.width,MAXFLOAT);
    NSDictionary *attributes = @{ NSFontAttributeName: self.font};
    CGRect bounds = [testText boundingRectWithSize:constraint options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes:attributes context:nil];
    return bounds.size.height;
#endif
}

- (void) textViewDidChange:(UITextView *)textView {

    CGRect frame = self.bounds;
    CGSize offsets = CGSizeMake(10.0, 16.0);

    frame.size.height -= offsets.height;
    frame.size.width -= offsets.width;


	CGFloat textHeight = [self.attributedText boundingRectWithSize:CGSizeMake(CGRectGetWidth(frame), MAXFLOAT)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                     context:nil].size.height;

    textHeight = textHeight == _singleLineContentHeight ? _minHeight : textHeight + offsets.height;
    
    CGFloat targetViewHeight = MIN(_maxHeight, MAX(_minHeight, textHeight)); // clamp the text height

    //NSLog(@"minHeight: %f view height: %f textHeight: %f lineHeight: %f", _minHeight, self.frame.size.height, self.contentSize.height, self.font.lineHeight);

	if (self.frame.size.height != targetViewHeight) {

        if (_animateHeightChange) {
            [self animateTextViewToHeight: targetViewHeight];
        } else {
            [self resizeTextView:targetViewHeight];
            // [fixed] The growingTextView:didChangeHeight: delegate method was not called at all when not animating height changes.
            // thanks to Gwynne <http://blog.darkrainfall.org/>

            if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
                [delegate growingTextView:self didChangeHeight:targetViewHeight];
            }
        }
	}

    // if our text height is greater than the maxHeight
    // enable scrolling. Otherwise disable it.
    if (textHeight > _maxHeight) {
        if(!self.scrollEnabled){
            self.scrollEnabled = YES;
            [self flashScrollIndicators];
        }
    } else {
        self.scrollEnabled = NO;
    }
}

- (void) animateTextViewToHeight:(CGFloat) newHeight {
    if ([UIView resolveClassMethod:@selector(animateWithDuration:animations:)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        [UIView animateWithDuration:0.1f
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                         animations:^(void) { [self resizeTextView:newHeight]; }
                         completion:^(BOOL finished) {
                             if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
                                 [delegate growingTextView:self didChangeHeight:newHeight];
                             }
                         }];
#endif
    } else {
        [UIView beginAnimations:@"" context:nil];
        [UIView setAnimationDuration:0.1f];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(growDidStop)];
        [UIView setAnimationBeginsFromCurrentState:YES];
        [self resizeTextView:newHeight];
        [UIView commitAnimations];
    }

}

- (void) resizeTextView:(CGFloat)newHeight {
    if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:)]) {
        [delegate growingTextView:self willChangeHeight:newHeight];
    }
    
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = newHeight; // + padding

    // TODO: handle padding
    internalTextViewFrame.size.width = self.contentSize.width;
    
    self.frame = internalTextViewFrame;
}

- (void) growDidStop {
	if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
		[delegate growingTextView:self didChangeHeight:self.frame.size.height];
	}
	
}

- (id<UITextViewDelegate,GrowingTextViewDelegate>) delegate {
    return delegate;
}

- (void) setDelegate: (id<UITextViewDelegate,GrowingTextViewDelegate>) aDelegate {
    [super setDelegate: aDelegate];
    delegate = aDelegate;
}

- (void) setMaxHeight:(CGFloat)maxHeight {
    _maxHeight = maxHeight;

    [self performSelector: @selector(textViewDidChange:) withObject: self];
}

- (void) setText:(NSString *)newText {
    BOOL originalValue = self.scrollEnabled;
    //If one of GrowingTextView's superviews is a scrollView, and self.scrollEnabled == NO,
    //setting the text programatically will cause UIKit to search upwards until it finds a scrollView with scrollEnabled==yes
    //then scroll it erratically. Setting scrollEnabled temporarily to YES prevents this.
    [self setScrollEnabled:YES];
    [super setText: newText];
    [self setScrollEnabled:originalValue];
    
    [self performSelector:@selector(textViewDidChange:) withObject: self];
}

- (void) setContentOffset:(CGPoint)s {
	if (self.tracking || self.decelerating) {
		//initiated by user...

        UIEdgeInsets insets = self.contentInset;
        insets.bottom = 0;
        insets.top = 0;
        self.contentInset = insets;

	} else {

		float bottomOffset = (self.contentSize.height - self.frame.size.height + self.contentInset.bottom);
		if (s.y < bottomOffset && self.scrollEnabled) {
            UIEdgeInsets insets = self.contentInset;
            insets.bottom = 4; //8;
            insets.top = 0;
            self.contentInset = insets;
        }
	}

	[super setContentOffset:s];
}

- (void) setContentInset:(UIEdgeInsets)s {
	UIEdgeInsets insets = s;
	if (s.bottom>8) insets.bottom = 0;
	insets.top = 0;

    // TODO: this is *the* hot spot ... 
    insets.top = -5;
    //insets.bottom = 0;

	[super setContentInset:insets];
    //NSLog(@"insets t: %f b: %f l: %f r: %f", self.contentInset.top, self.contentInset.bottom, self.contentInset.left, self.contentInset.right);
}

- (void) setContentSize:(CGSize)contentSize {
    // is this an iOS5 bug? Need testing!
    if (self.contentSize.height > contentSize.height) {
        UIEdgeInsets insets = self.contentInset;
        insets.bottom = 0;
        insets.top = 0;
        self.contentInset = insets;
    }

    [super setContentSize:contentSize];
}


///////////////////////////////////////////////////////////////////////////////////////////////////

- (void) setFont:(UIFont *)afont {
	[super setFont:afont];
}

@end
