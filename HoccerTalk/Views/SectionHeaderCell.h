//
//  SectionHeaderCell.h
//  HoccerTalk
//
//  Created by David Siegel on 28.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SectionHeaderCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *label;

+ (NSString *)reuseIdentifier;

@end
