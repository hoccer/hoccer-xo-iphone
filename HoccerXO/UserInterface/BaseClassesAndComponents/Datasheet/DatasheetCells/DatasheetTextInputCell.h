//
//  DatasheetTextInputCell.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetCell.h"

@interface DatasheetTextInputCell : DatasheetCell <UITextFieldDelegate>

@property (nonatomic,readonly) UITextField * valueView;

@end
