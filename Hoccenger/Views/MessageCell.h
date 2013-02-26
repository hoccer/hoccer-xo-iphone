//
//  MessageCell.h
//  Hoccenger
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AutoheightLabel.h"

@interface MessageCell : UITableViewCell

@property (strong, nonatomic) IBOutlet AutoheightLabel *message;
@property (strong, nonatomic) IBOutlet UIImageView *myAvatar;
@property (strong, nonatomic) IBOutlet UIImageView *yourAvatar;

- (float) heightForText: (NSString*) text;
+ (NSString *)reuseIdentifier;

@end
