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

@property (nonatomic, strong) IBOutlet UILabel *playlistStatusLabel;
@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *artistLabel;
@property (nonatomic, strong) IBOutlet UILabel *currentTimeLabel;
@property (nonatomic, strong) IBOutlet UILabel *remainingTimeLabel;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;
@property (nonatomic, strong) IBOutlet UIButton *playButton;
@property (nonatomic, strong) IBOutlet UIButton *skipBackButton;
@property (nonatomic, strong) IBOutlet UIButton *skipForwardButton;
@property (nonatomic, strong) IBOutlet UIButton *repeatButton;
@property (nonatomic, strong) IBOutlet UIButton *shuffleButton;
@property (nonatomic, strong) IBOutlet UISlider *seekSlider;
@property (nonatomic, strong) IBOutlet UIImageView *artworkImageView;
@property (nonatomic, strong) IBOutlet UIImageView *volumeDownImageView;
@property (nonatomic, strong) IBOutlet UIImageView *volumeUpImageView;

@end
