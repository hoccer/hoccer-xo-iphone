//
//  ChatBar.m
//  HoccerXO
//
//  Created by David Siegel on 30.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatBar.h"

#import "PaperClip.h"
#import "PaperDart.h"
#import "HXOTheme.h"

extern const CGFloat kHXOGridSpacing;

@implementation ChatBar

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    float s = 44;

    _attachmentButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [_attachmentButton setImage: [[PaperClip alloc] init].image forState: UIControlStateNormal];
    _attachmentButton.frame = CGRectMake(0, 0, s, s);
    _attachmentButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self addSubview: _attachmentButton];

    UIFont * font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    CGFloat height = MIN(150, MAX( s - 2 * kHXOGridSpacing, 0));

    _messageField = [[UITextView alloc] initWithFrame: CGRectMake(s + kHXOGridSpacing, kHXOGridSpacing, self.bounds.size.width - 2 * s, height)];
    _messageField.autoresizingMask = UIViewAutoresizingFlexibleWidth/* | UIViewAutoresizingFlexibleHeight*/;
    _messageField.backgroundColor = [UIColor whiteColor];
    _messageField.layer.cornerRadius = kHXOGridSpacing / 2;
    _messageField.layer.borderWidth = 1.0;
    _messageField.layer.borderColor = [HXOTheme theme].messageFieldBorderColor.CGColor;
    _messageField.font = font;
    _messageField.textContainerInset = UIEdgeInsetsMake(6, 0, 2, 0);
    _messageField.text = @"k";
    [self addSubview: _messageField];
    _messageField.text = @"";

    _sendButton = [UIButton buttonWithType: UIButtonTypeSystem];
    [_sendButton setImage: [[PaperDart alloc] init].image forState: UIControlStateNormal];
    _sendButton.frame = CGRectMake(CGRectGetMaxX(_messageField.frame), 0, s, s);
    _sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self addSubview: _sendButton];
}

- (void) dealloc {
}
@end
