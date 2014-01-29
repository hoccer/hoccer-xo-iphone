//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactQuickListViewCells.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"
#import "InsetImageView.h"

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

    self.backgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
    self.backgroundView.frame = self.bounds;
    self.avatar.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.2];
    self.avatar.borderColor = [UIColor colorWithWhite: 0 alpha: 0.66];

    _messageCountBackground = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: @"bg_message-count-grey" withLeftCapWidth: 10 topCapHeight: 10]];
    [self.contentView addSubview: _messageCountBackground];
    [self.contentView sendSubviewToBack: _messageCountBackground];
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

@implementation ContactQuickListSectionHeaderView

- (id) init {
    self = [super initWithFrame: CGRectMake(0, 0, 320, 24)];
    if (self != nil) {
        self.title = [[UILabel alloc] initWithFrame: self.frame];
        [self addSubview: self.title];
        self.title.backgroundColor = [UIColor clearColor];
        self.title.font = [UIFont systemFontOfSize: 12];
        self.title.textColor = [UIColor colorWithWhite: 0.2 alpha: 1];
        self.title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.title.textAlignment = NSTextAlignmentCenter;
        self.backgroundColor = [UIColor colorWithWhite: 0.7 alpha: 1.0];

    }
    return self;
}

@end
