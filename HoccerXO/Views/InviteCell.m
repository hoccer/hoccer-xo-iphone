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
    //UIImage * buttonBackground = [[UIImage imageNamed: @"button-large"] stretchableImageWithLeftCapWidth: 4 topCapHeight: 0];
    // [self.button setBackgroundImage: buttonBackground forState: UIControlStateNormal];
   // self.button.backgroundColor = [UIColor clearColor];
    self.button.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
    self.button.titleLabel.textAlignment = NSTextAlignmentCenter;
    // self.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed: @"button-large-background"]];
    // self.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed: @"button-large-background"]];
    //self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];
}

@end
