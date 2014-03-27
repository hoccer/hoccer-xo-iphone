//
//  DatasheetFooterTextView.h
//  HoccerXO
//
//  Created by David Siegel on 27.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HXOHyperLabel;

@interface DatasheetFooterTextView : UITableViewHeaderFooterView

@property (nonatomic,strong) HXOHyperLabel * label;

@end
