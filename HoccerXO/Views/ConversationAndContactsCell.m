//
//  ConversationAndContactsCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationAndContactsCell.h"
#import "InsetImageView.h"
#import "QuartzCore/QuartzCore.h"

#import "AssetStore.h"

@implementation ConversationAndContactsCell

- (void) awakeFromNib {
    _avatar.layer.cornerRadius = 10;
    _avatar.clipsToBounds = YES;

    self.nickName.font = [UIFont boldSystemFontOfSize: 14];
}

@end
