//
//  MessageCell.h
//  Hoccenger
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AutoheightLabel.h"

@class AvatarBezelView;

@interface MessageCell : UITableViewCell

@property (strong, nonatomic) IBOutlet AutoheightLabel *myMessage;
@property (strong, nonatomic) IBOutlet AvatarBezelView *myAvatar;
@property (strong, nonatomic) IBOutlet AvatarBezelView *yourAvatar;
@property (strong, nonatomic) IBOutlet AutoheightLabel *yourMessage;

- (float) heightForText: (NSString*) text;
+ (NSString *)reuseIdentifier;

@end
