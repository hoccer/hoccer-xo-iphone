//
//  MessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"
#import "AutoheightLabel.h"
#import "HXOMessage.h"
#import "InsetImageView.h"


const CGFloat kHXOGridSpacing = 8; // TODO: make this global
static const CGFloat kHXOAvatarSize = 5 * kHXOGridSpacing;
static const CGFloat kHXOBubbleMinimumHeight = 6 * kHXOGridSpacing;

@implementation MessageCell

- (id) init {
    self = [super init];
    if (self) {
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
    _sections = [NSMutableArray array];

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentMode = UIViewContentModeRedraw;
    self.backgroundColor = [UIColor clearColor];

    //self.colorScheme = HXOBubbleColorSchemeIncoming;
    self.messageDirection = HXOMessageDirectionOutgoing;

    _avatar = [UIButton buttonWithType: UIButtonTypeCustom];
    CGFloat y = self.frame.size.height - (kHXOAvatarSize + 2 * kHXOGridSpacing);

    _avatar.frame = CGRectMake(kHXOGridSpacing, y, kHXOAvatarSize, kHXOAvatarSize);
    _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    _avatar.clipsToBounds = YES;
    _avatar.layer.cornerRadius = 0.5 * _avatar.frame.size.width;
    _avatar.imageView.contentMode = UIViewContentModeScaleAspectFill;
    [self addSubview: _avatar];
    [_avatar addTarget: self action: @selector(avatarPressed:) forControlEvents: UIControlEventTouchUpInside];

    _subtitle = [[UILabel alloc] initWithFrame: CGRectMake(8 * kHXOGridSpacing, self.frame.size.height - 2 * kHXOGridSpacing, self.bubbleWidth - 4 * kHXOGridSpacing, 2 * kHXOGridSpacing)];
    _subtitle.font = [UIFont systemFontOfSize: 10];
    _subtitle.textColor = [UIColor colorWithWhite: 0.5 alpha: 1.0];
    _subtitle.backgroundColor = [UIColor clearColor];
    _subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self addSubview: _subtitle];
}

- (void) avatarPressed: (id) sender {
    if (self.delegate != nil) {
        [self.delegate messageCellDidPressAvatar: self];
    }
}

- (void) setMessageDirection:(HXOMessageDirection)messageDirection {
    _messageDirection = messageDirection;
    CGRect avatarFrame = _avatar.frame;
    if (messageDirection == HXOMessageDirectionIncoming) {
        avatarFrame.origin.x = kHXOGridSpacing;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        _subtitle.textAlignment = NSTextAlignmentLeft;
    } else {
        avatarFrame.origin.x = self.bounds.size.width - avatarFrame.size.width - kHXOGridSpacing;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _subtitle.textAlignment = NSTextAlignmentRight;
    }
    _avatar.frame = avatarFrame;

    CGFloat x = self.messageDirection == HXOMessageDirectionIncoming ? 6 * kHXOGridSpacing : 0;
    CGRect frame;
    NSUInteger i = 0;
    for (MessageSection * section in self.sections) {
        frame = section.frame;
        frame.origin.x = x;
        section.frame = frame;
        if (self.sections.count == 1) {
            section.position = HXOSectionPositionSingle;
        } else if (i == 0) {
            section.position = HXOSectionPositionFirst;
        } else if (i == self.sections.count - 1) {
            section.position = HXOSectionPositionLast;
        } else {
            section.position = HXOSectionPositionInner;
        }
        i += 1;
        [section messageDirectionDidChange];
    }

    frame = self.subtitle.frame;
    frame.origin.x = x + 2 * kHXOGridSpacing;
    self.subtitle.frame = frame;
}


- (CGSize) sizeThatFits:(CGSize)size {
    CGFloat height = 0;
    CGSize sectionSize = CGSizeZero;
    CGSize bubbleSize = CGSizeMake([self bubbleWidthForWidth: size.width], size.height);
    for (MessageSection * section in self.sections) {
        sectionSize = [section sizeThatFits: bubbleSize];
        height += sectionSize.height;
    }
    height += kHXOGridSpacing + (self.sections.count - 1) * kHXOGridSpacing + 2 * kHXOGridSpacing;
    return CGSizeMake(size.width, height);
}

- (void) addSection:(MessageSection *)section {
    section.cell = self;
    section.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.sections addObject: section];
    [self addSubview: section];
}

- (void) layoutSubviews {
    CGFloat y = kHXOGridSpacing;
    for (MessageSection * section in self.sections) {
        [section sizeToFit];
        CGRect frame = section.frame;
        frame.origin.y = y;
        section.frame = frame;
        y += frame.size.height + kHXOGridSpacing;
    }
}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    _colorScheme = colorScheme;
    for (MessageSection * section in self.sections) {
        [section colorSchemeDidChange];
    }
    self.subtitle.textColor = [self subtitleColor];
    [self setNeedsDisplay];
}

- (CGFloat) bubbleWidth {
    return [self bubbleWidthForWidth: self.bounds.size.width];
}

- (CGFloat) bubbleWidthForWidth: (CGFloat) width {
    return width - 6 * kHXOGridSpacing;
}


// TODO: move this to MessageSection after BubbleViewToo is retiered
- (UIColor*) fillColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor colorWithRed: 0.902 green: 0.906 blue: 0.922 alpha: 1];
        case HXOBubbleColorSchemeSuccess:
            return [UIColor colorWithRed: 0.224 green: 0.753 blue: 0.702 alpha: 1];
        case HXOBubbleColorSchemeInProgress:
            return [UIColor colorWithRed: 0.725 green: 0.851 blue: 0.839 alpha: 1];
        case HXOBubbleColorSchemeFailed:
            return [UIColor colorWithRed: 0.741 green: 0.224 blue: 0.208 alpha: 1];
    }
}


- (UIColor*) textColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor blackColor];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}

- (UIColor*) subtitleColor {
    return [self fillColor];
}


-(BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self canPerformAction:action withSender:sender];
    }
    return NO;
}

-(BOOL)canBecomeFirstResponder {
    return YES;
}

-(void) saveMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self saveMessage:sender];
    }
}

-(void) resendMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self resendMessage:sender];
    }
}

-(void) forwardMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self forwardMessage:sender];
    }
}

-(void) copy:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self copy:sender];
    }
}

-(void) deleteMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self deleteMessage:sender];
    }
}
@end


