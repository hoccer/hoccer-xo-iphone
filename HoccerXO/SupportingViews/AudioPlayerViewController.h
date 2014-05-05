//
//  AudioPlayerViewController.h
//  HoccerXO
//
//  Created by Nico Nußbaum on 02/05/2014.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Attachment;

@interface AudioPlayerViewController : UIViewController

@property (nonatomic, strong) Attachment *audioAttachment;

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UIButton *playButton;

@end
