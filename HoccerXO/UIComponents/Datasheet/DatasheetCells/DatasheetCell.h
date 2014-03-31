//
//  DatasheetCell.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewCell.h"

@class DatasheetCell;

@protocol DatasheetCellDelegate <NSObject>

- (void) datasheetCell: (DatasheetCell*) cell didChangeValueForView: (id) valueView;
- (BOOL) datasheetCell: (DatasheetCell*) cell shouldChangeValue: (id) oldValue toNewValue: (id) newValue;

@end

@interface DatasheetCell : HXOTableViewCell

@property (nonatomic,readonly) UILabel * titleLabel;

- (void) commonInit;
- (void) preferredContentSizeChanged: (NSNotification*) notification;

@property (nonatomic,weak) id<DatasheetCellDelegate> delegate;

@end

