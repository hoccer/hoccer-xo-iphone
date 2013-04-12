//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactQuickListViewCells.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"

@interface ContactQuickListCell ()
{
    UIImageView * _messageCountBackground;
}

@property (nonatomic,strong) IBOutlet UILabel * messageCount;

@end

static const CGFloat kMessageCountBackgroundPadding = 8.0;
static const CGFloat kSectionHeaderShadowRaius = 2.0;

@implementation ContactQuickListCell

- (void) awakeFromNib {
    [super awakeFromNib];
    _messageCountBackground = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: @"bg_message-count-grey" withLeftCapWidth: 10 topCapHeight: 10]];
    [self addSubview: _messageCountBackground];
    [self sendSubviewToBack: _messageCountBackground];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGRect frame = _messageCount.frame;
    frame.size.height = _messageCountBackground.image.size.height;
    frame.origin.x -= kMessageCountBackgroundPadding;
    frame.size.width += 2 * kMessageCountBackgroundPadding;
    _messageCountBackground.frame = frame;
}

- (void) setMessageCount: (NSInteger) count isUnread: (BOOL) unreadFlag {

    _messageCount.text = [@(count) stringValue];
    _messageCount.highlighted = unreadFlag;
    CGFloat rightEdge = _messageCount.frame.origin.x + _messageCount.frame.size.width;
    [_messageCount sizeToFit];
    CGRect frame = _messageCount.frame;
    frame.origin.x = rightEdge - frame.size.width;
    _messageCount.frame = frame;
    _messageCountBackground.image = [AssetStore stretchableImageNamed: unreadFlag ? @"bg_message-count-red" : @"bg_message-count-grey" withLeftCapWidth: 10 topCapHeight: 10];
    frame.size.height = _messageCountBackground.image.size.height;
    frame.origin.x -= kMessageCountBackgroundPadding;
    frame.size.width += 2 * kMessageCountBackgroundPadding;
    _messageCountBackground.frame = frame;
}

@end

@implementation ContactQuickListSectionHeaderCell

- (void) awakeFromNib {
    self.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed: @"contact_section_header_bg"]];
}

- (void) layoutSubviews {
    CGFloat r = kSectionHeaderShadowRaius;
    [super layoutSubviews];
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.8;
    self.layer.shadowRadius = r;
    self.layer.shadowOffset = CGSizeMake(0.0, r);
    CGRect shadowRect = CGRectMake(- 2 * r, 0, self.bounds.size.width + 4 * r, self.bounds.size.height);
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect: shadowRect].CGPath;
}

@end
