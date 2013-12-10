//
//  MessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatTableCells.h"
#import "AutoheightLabel.h"
#import "HXOMessage.h"
#import "InsetImageView.h"


static const CGFloat kHXOGridSpacing = 8; // TODO: make this global
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

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentMode = UIViewContentModeRedraw;
    self.backgroundColor = [UIColor clearColor];

    //self.colorScheme = HXOBubbleColorSchemeIncoming;
    self.messageDirection = HXOMessageDirectionOutgoing;

    _avatar = [UIButton buttonWithType: UIButtonTypeCustom];
    CGFloat y = self.frame.size.height - (kHXOAvatarSize + kHXOGridSpacing);

    _avatar.frame = CGRectMake(kHXOGridSpacing, y, kHXOAvatarSize, kHXOAvatarSize);
    _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    _avatar.clipsToBounds = YES;
    _avatar.layer.cornerRadius = 0.5 * _avatar.frame.size.width;
    [self addSubview: _avatar];
    [_avatar addTarget: self action: @selector(avatarPressed:) forControlEvents: UIControlEventTouchUpInside];

    _avatar.backgroundColor = [UIColor orangeColor];

    // TODO: set correct frame;
    _subtitle = [[UILabel alloc] initWithFrame: CGRectMake(kHXOAvatarSize + 2 * kHXOGridSpacing, self.frame.size.height - kHXOGridSpacing, kHXOBubbleMinimumHeight + 2 * kHXOGridSpacing, 10)];
    _subtitle.font = [UIFont systemFontOfSize: 8];
    _subtitle.textColor = [UIColor colorWithWhite: 0.5 alpha: 1.0];
    _subtitle.backgroundColor = [UIColor clearColor];
    _subtitle.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self addSubview: _subtitle];


}

- (void) setMessageDirection:(HXOMessageDirection)messageDirection {
    _messageDirection = messageDirection;
    CGRect frame = _avatar.frame;
    if (messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x = kHXOGridSpacing;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
        _subtitle.textAlignment = NSTextAlignmentLeft;
    } else {
        frame.origin.x = self.bounds.size.width - frame.size.width - kHXOGridSpacing;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _subtitle.textAlignment = NSTextAlignmentRight;
    }
    _avatar.frame = frame;
    [self setNeedsLayout];
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


/*
@implementation ChatTableSectionHeaderCell

#if 0
// We dont't need it right now, but may come in handy for doing some section navigation
- (void) awakeFromNib {
    [super awakeFromNib];
    //[self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)]]; // add non-working longpress gesture recognizer to avoid crash
    self.userInteractionEnabled = NO;
    self.label.userInteractionEnabled = NO;
    self.backgroundImage.userInteractionEnabled = NO;
}
-(BOOL) canPerformAction:(SEL)action withSender:(id)sender {
     NSLog(@"ChatTableSectionHeaderCell:canPerformAction");
     return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    NSLog(@"ChatTableSectionHeaderCell:gestureRecognizerShouldBegin");
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    NSLog(@"ChatTableSectionHeaderCell:shouldReceiveTouch");
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    NSLog(@"ChatTableSectionHeaderCell:shouldRecognizeSimultaneouslyWithGestureRecognizer");
    return NO;
}

-(void)handleLongPress:(UILongPressGestureRecognizer*)longPressRecognizer {
    NSLog(@"ChatTableSectionHeaderCell:handleLongPress");
}
#endif


@end
 */

