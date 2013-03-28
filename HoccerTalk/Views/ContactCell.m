//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"
#import "AssetStore.h"

@interface ContactCell ()
{
    UIImageView * _messageCountBackground;
}

@property (nonatomic,strong) IBOutlet UILabel * messageCount;

@end

static const CGFloat kMessageCountBackgroundPadding = 8.0;

@implementation ContactCell

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}

- (void) awakeFromNib {
    [super awakeFromNib];
    _messageCountBackground = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: @"bg_message-count-grey" withLeftCapWidth: 10 topCapHeight: 10]];
    CGRect frame = _messageCount.frame;
    frame.size.height = _messageCountBackground.image.size.height;
    _messageCountBackground.frame = frame;
    [self addSubview: _messageCountBackground];
    [self sendSubviewToBack: _messageCountBackground];
}

- (void) setMessageCount: (NSInteger) count isUnread: (BOOL) unreadFlag {

    _messageCount.text = [[NSNumber numberWithInteger: count] stringValue];
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
