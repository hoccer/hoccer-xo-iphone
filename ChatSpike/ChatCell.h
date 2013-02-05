//
//  ChatTableViewCell.h
//  ChatSpike
//
//  Created by David Siegel on 05.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ChatCell : UITableViewCell

@property (nonatomic,weak) IBOutlet UILabel* label;

+ (ChatCell*) cell;
+ (NSString *)reuseIdentifier;
+ (float) heightForText: (NSString*) text;

@end
