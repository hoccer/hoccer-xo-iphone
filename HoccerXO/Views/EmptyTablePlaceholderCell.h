//
//  EmptyTablePlaceholderCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@interface EmptyTablePlaceholderCell : HXOTableViewCell

@property (strong, nonatomic) IBOutlet UILabel *placeholder;
@property (strong, nonatomic) IBOutlet UIImageView *icon;

@end
