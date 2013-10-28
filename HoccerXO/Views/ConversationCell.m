//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationCell.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"

static const CGFloat kHXOTimeDirectionPading = 2.0;

@interface ConversationCell () {
    BOOL _hasNewMessages;
}
@end

@implementation ConversationCell

- (void) awakeFromNib {
    [super awakeFromNib];
    //[self engraveLabel: self.latestMessageLabel];
    //[self engraveLabel: self.latestMessageTimeLabel];
}

- (void) setHasNewMessages:(BOOL)hasNewMessages {
    _hasNewMessages = hasNewMessages;
    self.unreadMessageBackground.hidden = ! _hasNewMessages;
}

- (void) layoutSubviews {
    [super layoutSubviews];

    [self.latestMessageTimeLabel sizeToFit];

    CGRect frame = self.latestMessageTimeLabel.frame;
    if (self.latestMessageDirection.image == nil) {
        frame.origin.x = (self.latestMessageDirection.frame.origin.x + self.latestMessageDirection.frame.size.width) - frame.size.width;
    } else {
        frame.origin.x = self.latestMessageDirection.frame.origin.x - (kHXOTimeDirectionPading + frame.size.width);
    }
    self.latestMessageTimeLabel.frame = frame;

    frame = self.nickName.frame;
    frame.size.width = self.latestMessageTimeLabel.frame.origin.x - (kHXOTimeDirectionPading + frame.origin.x);
    self.nickName.frame = frame;
}

- (UIView*) unreadMessageBackground {
    if (_unreadMessageBackground == nil) {
        _unreadMessageBackground = [[UIView alloc] initWithFrame: CGRectMake(15, 0, self.bounds.size.width, self.bounds.size.height)];
        _unreadMessageBackground.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
        [self.contentView insertSubview: _unreadMessageBackground atIndex: 0];
    }
    return _unreadMessageBackground;
}

@end
