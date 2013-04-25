//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"

@implementation ContactCell

- (void) awakeFromNib {
    [super awakeFromNib];

    [self engraveLabel: self.nickName];
    self.nickName.textColor = [UIColor colorWithWhite: 0.2 alpha: 1.0];
    self.accessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"user_defaults_disclosure_arrow"]];
}
@end
