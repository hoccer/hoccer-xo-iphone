//
//  DataSheetController.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@class DataSheetController;

typedef enum DataSheetChangeTypes {
    DataSheetChangeInsert,
    DataSheetChangeDelete,
    DataSheetChangeMove,
    DataSheetChangeUpdate
} DataSheetChangeType;

@protocol DataSheetControllerDelegate <NSObject>

- (void) controllerWillChangeContent: (DataSheetController*) controller;
- (void) controller: (DataSheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DataSheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath;
- (void) controller: (DataSheetController*) controller didChangeSection: (NSUInteger) sectionIndex;
- (void) controllerDidChangeContent: (DataSheetController*) controller;

@end

@interface DataSheetItem : NSObject

@property (nonatomic, strong) NSString * cellIdentifier;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSString * valuePath;
@property (nonatomic, strong) NSString * placeholder;

@property (nonatomic, weak) DataSheetController * delegate;

+ (id) dataSheetItem;

@end

@interface DataSheetSection : NSObject

@property (nonatomic,strong) NSArray * items;
@property (nonatomic,strong) NSAttributedString * footerText;

+ (id) dataSheetSection;

@end

@interface DataSheetController : NSObject

@property (nonatomic,weak) id<DataSheetControllerDelegate> delegate;
@property (nonatomic,strong) NSArray * items;

@property (nonatomic,strong) NSArray * cellClasses;

@property (nonatomic,strong) id inspectedObject;

- (id) valueForItem: (DataSheetItem*) item;

- (DataSheetItem*) itemWithTitle: (NSString*) titleKey cellIdentifier: (NSString*) cellIdentifier;
- (DataSheetItem*) itemForIndexPath: (NSIndexPath*) indexPath;

@end
