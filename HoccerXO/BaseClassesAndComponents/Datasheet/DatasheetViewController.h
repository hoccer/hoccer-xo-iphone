//
//  DatasheetViewController.h
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewController.h"

#import "DatasheetController.h"
#import "DatasheetCell.h"
#import "HXOHyperLabel.h"

@interface DatasheetViewController : HXOTableViewController <DatasheetControllerDelegate, DatasheetCellDelegate, HXOHyperLabelDelegate>

@property (nonatomic,strong) IBOutlet DatasheetController * dataSheetController;
@property (nonatomic,strong) id                             inspectedObject;

- (IBAction) unwindToSheetView: (UIStoryboardSegue*) unwindSegue;

@end
