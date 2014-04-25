//
//  AudioAttachmentListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentListViewController.h"

#import "tab_settings.h"

@implementation AudioAttachmentListViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSString *title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
    self.tabBarItem.image = [[[tab_settings alloc] init] image];
    self.tabBarItem.title = title;
    self.navigationItem.title = title;
}

@end
