//
//  MessageCell.h
//  HoccerTalk
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AutoheightLabel;
@class AvatarBezelView;
@class BubbleView;

@interface MessageCell : UITableViewCell

@property (strong, nonatomic) IBOutlet AutoheightLabel *message;
@property (strong, nonatomic) IBOutlet AvatarBezelView *avatar;
@property (strong, nonatomic) IBOutlet BubbleView *bubble;

- (float) heightForText: (NSString*) text;

@end
