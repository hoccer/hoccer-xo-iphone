//
//  MessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"
#import "HXOUI.h"
#import "HXOUI.h"

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

    self.backgroundColor = [UIColor clearColor];

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentMode = UIViewContentModeRedraw;

    self.messageDirection = HXOMessageDirectionOutgoing;

    CGFloat y = self.contentView.frame.size.height - (kHXOChatAvatarSize + 2 * kHXOGridSpacing);
    _avatar = [[HXOAvatarButton alloc] initWithFrame:CGRectMake(kHXOGridSpacing, y, kHXOChatAvatarSize, kHXOChatAvatarSize)];
    _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.contentView addSubview: _avatar];
    [_avatar addTarget: self action: @selector(avatarPressed:) forControlEvents: UIControlEventTouchUpInside];

    _subtitle = [[UILabel alloc] initWithFrame: CGRectMake(8 * kHXOGridSpacing, self.frame.size.height - 2 * kHXOGridSpacing, self.bubbleWidth - 4 * kHXOGridSpacing, 2 * kHXOGridSpacing)];
    _subtitle.font = [UIFont systemFontOfSize: 10];
    _subtitle.textColor = [UIColor colorWithWhite: 0.5 alpha: 1.0];
    _subtitle.backgroundColor = [UIColor clearColor];
    _subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.contentView addSubview: _subtitle];
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
        avatarFrame.origin.x = self.contentView.bounds.size.width - avatarFrame.size.width - kHXOGridSpacing;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _subtitle.textAlignment = NSTextAlignmentRight;
    }
    _avatar.frame = avatarFrame;

    CGFloat x = messageDirection == HXOMessageDirectionIncoming ? 6 * kHXOGridSpacing : 0;
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
    [self.contentView addSubview: section];
}

- (void) layoutSubviews {
    [super layoutSubviews];
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
    self.subtitle.textColor = [[HXOUI theme] messageFooterTextColorForScheme: self.colorScheme];
    [self setNeedsDisplay];
}

- (CGFloat) bubbleWidth {
    return [self bubbleWidthForWidth: self.bounds.size.width];
}

- (CGFloat) bubbleWidthForWidth: (CGFloat) width {
    return width - 6 * kHXOGridSpacing;
}

-(BOOL) canPerformAction:(SEL)action withSender:(id)sender {
    // NSLog(@"MessageCell: canPerformAction %s withSender %@, delegate=%@", sel_getName(action), sender, self.delegate);
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
/*
-(void) forwardMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self forwardMessage:sender];
    }
}
*/

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

-(void) openWithMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self openWithMessage:sender];
    }
}

-(void) shareMessage:(id)sender {
    if (self.delegate != nil) {
        return [self.delegate messageCell:self shareMessage:sender];
    }
}

@end


