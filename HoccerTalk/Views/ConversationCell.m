//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationCell.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"

@interface ConversationCell ()

@end

@implementation ConversationCell

- (void) awakeFromNib {
    self.backgroundView = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: @"conversation_cell_bg" withLeftCapWidth: 1.0 topCapHeight: 0]];
    [self engraveLabel: self.latestMessage];
    [self engraveLabel: self.latestMessageTime];
}

- (void) engraveLabel: (UILabel*) label {
    label.textColor = [UIColor darkGrayColor];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(0.0, 1.0);

}

@end
