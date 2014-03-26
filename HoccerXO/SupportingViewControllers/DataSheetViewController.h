//
//  DataSheetViewController.h
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewController.h"

#import "DataSheetController.h"

@interface DataSheetViewController : HXOTableViewController <DataSheetControllerDelegate>

@property (nonatomic,strong) IBOutlet DataSheetController * dataSheetController;

@end
