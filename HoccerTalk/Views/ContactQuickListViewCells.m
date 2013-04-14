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
    self.avatar.borderColor = [UIColor blackColor];

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

@implementation ContactQuickListSectionHeaderView

- (id) init {
    self = [super initWithFrame: CGRectMake(0, 0, 320, 24)];
    if (self != nil) {
        self.icon = [[UIImageView alloc] initWithFrame: CGRectMake(25, 0, 24, 24)];
        [self addSubview: self.icon];
        self.title = [[UILabel alloc] initWithFrame: CGRectMake(63, 0, 237, 24)];
        [self addSubview: self.title];
        self.title.backgroundColor = [UIColor clearColor];
        self.title.font = [UIFont boldSystemFontOfSize: 17];
        self.title.textColor = [UIColor colorWithWhite: 0.1 alpha: 1];
        self.title.shadowColor = [UIColor colorWithWhite: 0.60 alpha:1];
        self.title.shadowOffset = CGSizeMake(0, 1);
        self.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed: @"contact_section_header_bg"]];

    }
    return self;
}

- (void) layoutSubviews {
    NSLog(@"===== layoutSubview");
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
