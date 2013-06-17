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
    [self engraveLabel: self.latestMessageLabel];
    //[self engraveLabel: self.latestMessageTimeLabel];
    self.latestMessageTimeLabel.textColor = [UIColor colorWithWhite: 0.4 alpha: 1];
}

- (void) setHasNewMessages:(BOOL)hasNewMessages {
    UIImage * backgroundImage = nil;
    _hasNewMessages = hasNewMessages;
    if (hasNewMessages) {
        backgroundImage = [AssetStore stretchableImageNamed: @"conversation_cell_bg_new" withLeftCapWidth: 1.0 topCapHeight: 0];
    } else {
        backgroundImage = [AssetStore stretchableImageNamed: @"conversation_cell_bg" withLeftCapWidth: 1.0 topCapHeight: 0];
    }
    ((UIImageView*)self.backgroundView).image = backgroundImage;
    [self setNeedsDisplay];
}

- (NSString*) backgroundName {
    return @"conversation_cell_bg";
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

@end
