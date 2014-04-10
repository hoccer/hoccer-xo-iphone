//
//  HoccerXOTableViewCell.h
//  HoccerXO
//
//  Created by David Siegel on 09.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum HXOCellAccessoryAlignments {
    HXOCellAccessoryAlignmentTop,
    HXOCellAccessoryAlignmentCenter
} HXOCellAccessoryAlignment;

@interface HXOTableViewCell : UITableViewCell

+ (NSString*) reuseIdentifier;

@property (nonatomic,strong) UIView * hxoAccessoryView;
@property (nonatomic,assign) HXOCellAccessoryAlignment hxoAccessoryAlignment;
@property (nonatomic,assign) CGFloat hxoAccessoryXOffset;

@end
