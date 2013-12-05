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

- (void) setHasNewMessages:(BOOL)hasNewMessages {
    _hasNewMessages = hasNewMessages;
}

- (void) layoutSubviews {
    [super layoutSubviews];

    [self.latestMessageTimeLabel sizeToFit];

    CGRect frame = self.nickName.frame;
    frame.size.width = self.latestMessageTimeLabel.frame.origin.x - (kHXOTimeDirectionPading + frame.origin.x);
    self.nickName.frame = frame;
}

@end
