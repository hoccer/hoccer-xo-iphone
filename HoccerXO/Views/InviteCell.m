//
//  InviteCell.m
//  HoccerXO
//
//  Created by David Siegel on 25.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InviteCell.h"


@implementation InviteCell

- (void) awakeFromNib {
    [self.button setTitle: NSLocalizedString(@"invite_friends_button_title", nil) forState: UIControlStateNormal];
    UIImage * background = [[UIImage imageNamed: @"navbar-btn-blue"] stretchableImageWithLeftCapWidth: 4 topCapHeight: 0];
    [self.button setBackgroundImage: background forState: UIControlStateNormal];
    self.button.backgroundColor = [UIColor clearColor];
    self.button.titleLabel.textAlignment = NSTextAlignmentCenter;
}

@end
