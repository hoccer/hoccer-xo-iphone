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

@end
