//
//  SettingSwitchCell.m
//  HoccerTalk
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "SettingsCells.h"

@implementation SettingCell

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textLabel.textColor = [UIColor colorWithWhite: 0.2 alpha: 1.0];
    self.textLabel.shadowColor = [UIColor whiteColor];
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor colorWithWhite: 0.9 alpha: 1.0];
}


@end

@implementation SettingSwitchCell

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textLabel.font = [UIFont boldSystemFontOfSize: 14];
}

@end

@implementation SettingTextCell

@end
