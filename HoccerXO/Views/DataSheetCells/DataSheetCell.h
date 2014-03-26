//
//  DataSheetCell.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewCell.h"

@interface DataSheetCell : HXOTableViewCell

@property (nonatomic,readonly) UILabel * titleLabel;

- (void) commonInit;
- (void) preferredContentSizeChanged: (NSNotification*) notification;

@end
