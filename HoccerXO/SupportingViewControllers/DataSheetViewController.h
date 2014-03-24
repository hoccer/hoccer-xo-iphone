//
//  DataSheetViewController.h
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DataSheetController;

@protocol DataSheetControllerDelegate <NSObject>

- (void) controllerWillChangeContent: (DataSheetController*) controller;
- (void) controller: (DataSheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (int) type newIndexPath: (NSIndexPath*) newIndexPath;
- (void) controller: (DataSheetController*) controller didChangeSection: (NSUInteger) sectionIndex;
- (void) controllerDidChangeContent: (DataSheetController*) controller;

@end

@interface DataSheetController : NSObject

@property (nonatomic,weak)     id<DataSheetControllerDelegate> delegate;

@end


@interface DataSheetViewController : UITableViewController<DataSheetControllerDelegate>

@property (nonatomic,strong) DataSheetController * dataSheetController;

@end
