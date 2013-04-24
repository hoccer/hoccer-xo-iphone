//
//  ConversationAndContactsCell.m
//  HoccerTalk
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationAndContactsCell.h"
#import "InsetImageView.h"

#import "AssetStore.h"

@implementation ConversationAndContactsCell

- (void) awakeFromNib {
    self.backgroundView = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: @"conversation_cell_bg" withLeftCapWidth: 1.0 topCapHeight: 0]];
    self.avatar.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.2];
    self.avatar.borderColor = [UIColor blackColor];

}

- (void) engraveLabel: (UILabel*) label {
    label.textColor = [UIColor darkGrayColor];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(0.0, 1.0);

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
@end
