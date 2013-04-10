//
//  SettingSwitchCell.h
//  HoccerTalk
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@interface SettingCell : HoccerTalkTableViewCell

@end


@interface SettingSwitchCell : SettingCell

@property (nonatomic,strong) IBOutlet UISwitch * toggle;

@end

@interface SettingTextCell : SettingCell

@property (nonatomic,strong) IBOutlet UILabel * textLabel;

@end
