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

typedef enum DataSheetModes {
    DataSheetModeEdit = (1<<0),
    DataSheetModeView = (1<<1)
} DataSheetMode;

@protocol DataSheetControllerDelegate <NSObject>

- (void) controllerDidChangeObject: (DataSheetController*) controller;

- (void) controllerWillChangeContent: (DataSheetController*) controller;
- (void) controller: (DataSheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DataSheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath;
- (void) controller: (DataSheetController*) controller didChangeSection: (NSIndexPath*) indexPath forChangeType: (DataSheetChangeType) type;
- (void) controllerDidChangeContent: (DataSheetController*) controller;

@end

@interface DataSheetItem : NSObject

@property (nonatomic, strong) NSString * identifier;
@property (nonatomic, strong) NSString * cellIdentifier;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSString * valuePath;
@property (nonatomic, strong) NSString * placeholder;
@property (nonatomic, assign) NSUInteger visibilityMask;
@property (nonatomic, assign) NSUInteger enabledMask;

@property (nonatomic, weak) DataSheetController * delegate;

+ (id) dataSheetItem;

@end

@interface DataSheetSection : NSObject

@property (nonatomic, strong) NSString * identifier;
@property (nonatomic,strong) NSArray * items;
@property (nonatomic,strong) NSAttributedString * footerText;

+ (id) dataSheetSectionWithIdentifier: (NSString*) identifier;

@end

@interface DataSheetController : NSObject

@property (nonatomic,strong) id inspectedObject;

@property (nonatomic,weak) id<DataSheetControllerDelegate> delegate;
@property (nonatomic,strong) NSArray * items;
@property (nonatomic,readonly) NSArray * currentItems;
@property (nonatomic,assign) BOOL isEditable;
@property (nonatomic,readonly) DataSheetMode mode;
@property (nonatomic,readonly) BOOL isEditing;

- (id) valueForItem: (DataSheetItem*) item;

- (DataSheetItem*) itemWithIdentifier: (NSString*) titleKey cellIdentifier: (NSString*) cellIdentifier;
- (DataSheetItem*) itemForIndexPath: (NSIndexPath*) indexPath;


- (void) editModeChanged: (id) sender;
- (void) commonInit;

@end
